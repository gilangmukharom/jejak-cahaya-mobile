import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/safe_emit.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/mosque.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../data/game_repository.dart';

enum GeofenceStage {
  /// Belum diperiksa sama sekali.
  initial,

  /// Sedang meminta izin lokasi atau menunggu sinyal GPS.
  locating,

  /// Pemain berada di dalam area masjid — permainan terbuka.
  inside,

  /// Pemain di luar area — hanya permainan yang tertutup, sisa aplikasi tidak.
  outside,

  /// Izin ditolak, GPS mati, atau sinyal tidak didapat.
  locationBlocked,

  /// Gagal menghubungi server.
  error,
}

/// Masjid terdekat beserta jarak tempuh ke tepi areanya.
class NearestMosque extends Equatable {
  const NearestMosque({
    required this.mosque,
    required this.distanceM,
  });

  final Mosque mosque;

  /// Jarak ke titik pusat masjid, bukan ke tepi areanya.
  final double distanceM;

  /// Sisa jarak sampai masuk area bermain.
  double get metersToEnter =>
      (distanceM - mosque.radiusMeters).clamp(0, double.infinity);

  @override
  List<Object?> get props => [mosque.id, distanceM];
}

class GeofenceState extends Equatable {
  const GeofenceState({
    this.stage = GeofenceStage.initial,
    this.status,
    this.mosque,
    this.position,
    this.mosques = const [],
    this.nearest,
    this.failure,
  });

  final GeofenceStage stage;
  final GeofenceStatus? status;
  final Mosque? mosque;
  final PlayerPosition? position;

  /// Seluruh masjid yang bisa dimainkan, apa adanya dari server.
  final List<Mosque> mosques;

  /// Masjid terdekat dari posisi pemain. Sama dengan [mosque] ketika pemain
  /// sedang berada di dalam area.
  final NearestMosque? nearest;

  final Failure? failure;

  /// Apakah area permainan terbuka.
  bool get isUnlocked => stage == GeofenceStage.inside;

  /// Apakah pemeriksaan sudah menghasilkan jawaban, apa pun jawabannya.
  ///
  /// Inilah yang dipakai gerbang untuk memutuskan boleh meneruskan pemain ke
  /// dalam aplikasi — bukan [isUnlocked]. Bedanya adalah inti dari perubahan
  /// perilaku ini: berada di luar area bukan lagi alasan menahan seseorang di
  /// depan pintu.
  bool get isResolved =>
      stage == GeofenceStage.inside || stage == GeofenceStage.outside;

  /// Sisa jarak menuju area masjid, dalam meter.
  double? get metersAway => status?.metersToEnter ?? nearest?.metersToEnter;

  GeofenceState copyWith({
    GeofenceStage? stage,
    GeofenceStatus? status,
    Mosque? mosque,
    PlayerPosition? position,
    List<Mosque>? mosques,
    NearestMosque? nearest,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      GeofenceState(
        stage: stage ?? this.stage,
        status: status ?? this.status,
        mosque: mosque ?? this.mosque,
        position: position ?? this.position,
        mosques: mosques ?? this.mosques,
        nearest: nearest ?? this.nearest,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props =>
      [stage, status, mosque, position, mosques, nearest, failure];
}

/// Menegakkan Layer 1 — tetapi hanya atas bagian aplikasi yang memang permainan.
///
/// Cubit ini terus memantau posisi dan mengumumkan apakah pemain berada di
/// dalam area masjid. Yang berubah dari versi sebelumnya bukan cara ia
/// memeriksa, melainkan apa yang boleh dilakukan dengan jawabannya: dulu
/// jawaban "di luar" menahan pemain di layar gerbang dan mengunci seluruh
/// aplikasi; sekarang jawabannya hanya menutup peta dan pemindai, sementara
/// jadwal sholat, arah kiblat, koleksi, misi, dan profil tetap terbuka.
///
/// Alasannya sederhana. Aplikasi ini juga berisi hal-hal yang tidak ada
/// hubungannya dengan berada di masjid, dan mengunci semuanya berarti
/// menghukum orang karena belum berangkat.
///
/// Pengunciannya tetap bersifat pengalaman pengguna. Yang benar-benar mengikat
/// adalah pemeriksaan ulang di `POST /scan`; tanpa itu, keputusan di sisi client
/// bisa dilewati begitu saja.
///
/// Berumur sepanjang aplikasi (lihat `core/di/injection.dart`), sebab tiga
/// layar sekaligus bergantung padanya — gerbang, peta, dan pemindai — dan
/// ketiganya harus melihat jawaban yang sama persis pada saat yang sama.
class GeofenceCubit extends Cubit<GeofenceState> with SafeEmit<GeofenceState> {
  GeofenceCubit({
    required GameRepository repository,
    required LocationService locationService,
    required AppPreferences preferences,
  })  : _repository = repository,
        _location = locationService,
        _preferences = preferences,
        super(const GeofenceState());

  final GameRepository _repository;
  final LocationService _location;
  final AppPreferences _preferences;

  StreamSubscription<PlayerPosition>? _positionSubscription;

  /// Jeda antar pemeriksaan geofence ke server, dibedakan menurut keadaan.
  ///
  /// Kedua keadaan melayani kebutuhan yang berbeda. Saat pemain masih di luar
  /// area, pemeriksaan yang rapat itulah yang membuat peta terbuka sendiri
  /// beberapa detik setelah ia melangkah masuk — inti dari pengalamannya.
  /// Setelah berada di dalam, tidak ada lagi yang ditunggu: pemeriksaan hanya
  /// perlu cukup sering untuk menyadari kalau pemain berjalan keluar.
  static const Duration _checkIntervalOutside = Duration(seconds: 8);
  static const Duration _checkIntervalInside = Duration(seconds: 30);

  Duration get _minCheckInterval => state.stage == GeofenceStage.inside
      ? _checkIntervalInside
      : _checkIntervalOutside;
  DateTime? _lastCheckedAt;

  /// Menentukan masjid yang dimainkan lalu mulai memantau lokasi.
  Future<void> initialize({String? mosqueId}) async {
    emit(state.copyWith(stage: GeofenceStage.locating, clearFailure: true));

    try {
      final mosques = state.mosques.isNotEmpty
          ? state.mosques
          : await _repository.fetchMosques();

      if (mosques.isEmpty) {
        emit(
          state.copyWith(
            stage: GeofenceStage.error,
            failure: const UnknownFailure(
              message: 'Belum ada masjid yang tersedia untuk dijelajahi.',
            ),
          ),
        );
        return;
      }

      emit(state.copyWith(mosques: mosques));

      await _location.ensurePermission();
      final position = await _location.getCurrentPosition();

      await _evaluate(position, preferredMosqueId: mosqueId);
      await _startWatching();
    } on LocationFailure catch (failure) {
      emit(state.copyWith(
          stage: GeofenceStage.locationBlocked, failure: failure));
    } on Object catch (error) {
      emit(
        state.copyWith(
          stage: GeofenceStage.error,
          failure: FailureMapper.map(error),
        ),
      );
    }
  }

  /// Memeriksa ulang atas permintaan pengguna, melewati jeda otomatis.
  Future<void> refresh() async {
    if (state.mosques.isEmpty) {
      await initialize();
      return;
    }

    emit(state.copyWith(stage: GeofenceStage.locating, clearFailure: true));

    try {
      final position = await _location.getCurrentPosition();
      _lastCheckedAt = null;
      await _evaluate(position);
      await _startWatching();
    } on LocationFailure catch (failure) {
      emit(state.copyWith(
          stage: GeofenceStage.locationBlocked, failure: failure));
    } on Object catch (error) {
      emit(
        state.copyWith(
          stage: GeofenceStage.error,
          failure: FailureMapper.map(error),
        ),
      );
    }
  }

  Future<void> openLocationSettings() => _location.openSettings();

  Future<void> _startWatching() async {
    if (_positionSubscription != null) return;

    await _location.startTracking();

    _positionSubscription = _location.positionStream.listen((position) {
      final last = _lastCheckedAt;
      if (last != null && DateTime.now().difference(last) < _minCheckInterval) {
        // Posisi tetap disimpan agar radar tetap halus, hanya panggilan server
        // yang dijarangkan. Jarak ke masjid terdekat ikut dihitung ulang secara
        // lokal, sehingga kartu "di luar area" merapat sambil pemain berjalan
        // alih-alih melompat tiap delapan detik.
        emit(state.copyWith(
          position: position,
          nearest: _nearestTo(position),
        ));
        return;
      }

      unawaited(_evaluate(position));
    });
  }

  /// Masjid terdekat menurut perhitungan lokal.
  ///
  /// Rumusnya sama dengan yang dipakai server, jadi angkanya tidak akan
  /// berselisih dengan jawaban resmi yang datang beberapa detik kemudian.
  NearestMosque? _nearestTo(PlayerPosition position) {
    if (state.mosques.isEmpty) return null;

    NearestMosque? closest;
    for (final mosque in state.mosques) {
      final distance = LocationService.distanceMeters(
        fromLat: position.latitude,
        fromLon: position.longitude,
        toLat: mosque.latitude,
        toLon: mosque.longitude,
      );

      if (closest == null || distance < closest.distanceM) {
        closest = NearestMosque(mosque: mosque, distanceM: distance);
      }
    }

    return closest;
  }

  Future<void> _evaluate(
    PlayerPosition position, {
    String? preferredMosqueId,
  }) async {
    _lastCheckedAt = DateTime.now();

    final nearest = _nearestTo(position);

    // Masjid yang diperiksa adalah yang terdekat, bukan yang terakhir dibuka.
    // Dengan begitu seseorang yang berpindah ke masjid lain langsung bermain di
    // sana tanpa perlu memilih apa pun — dan kartu "di luar area" selalu
    // menunjuk masjid yang benar-benar paling mungkin ia datangi.
    final targetId = preferredMosqueId ??
        nearest?.mosque.id ??
        _preferences.lastMosqueId ??
        state.mosques.first.id;

    try {
      final status = await _repository.checkGeofence(
        mosqueId: targetId,
        position: position,
      );

      if (status.isInside) await _preferences.setLastMosqueId(targetId);

      emit(
        state.copyWith(
          stage: status.isInside ? GeofenceStage.inside : GeofenceStage.outside,
          status: status,
          mosque: status.mosque,
          position: position,
          nearest: nearest,
          clearFailure: true,
        ),
      );
    } on Object catch (error) {
      final failure = FailureMapper.map(error);

      // Jaringan yang putus sesaat tidak boleh mengubah keadaan yang sudah
      // diketahui. Selama sudah ada jawaban sebelumnya — di dalam maupun di
      // luar — jawaban itu dipertahankan, dan hanya jaraknya yang diperbarui
      // dari perhitungan lokal. Mengunci ulang di tengah permainan, atau
      // sebaliknya membuka gerbang karena servernya diam, sama-sama salah.
      if (state.isResolved && failure is NetworkFailure) {
        emit(state.copyWith(
          position: position,
          nearest: nearest,
          failure: failure,
        ));
        return;
      }

      emit(
        state.copyWith(
          stage: GeofenceStage.error,
          position: position,
          nearest: nearest,
          failure: failure,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _positionSubscription?.cancel();
    await _location.stopTracking();
    return super.close();
  }
}
