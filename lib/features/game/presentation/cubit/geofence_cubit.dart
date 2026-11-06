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
    this.pinnedMosqueId,
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

  /// Lokasi yang dipilih sendiri oleh pemain dari daftar lokasi.
  ///
  /// Null berarti aplikasi memilihkan sendiri yang terdekat — perilaku bawaan,
  /// dan yang benar bagi hampir semua orang. Pilihan manual berguna untuk
  /// kebalikannya: melihat-lihat lokasi yang belum didatangi, memeriksa
  /// misinya, dan memutuskan akan ke mana.
  final String? pinnedMosqueId;

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

  /// Apakah lokasi yang sedang dibuka berasal dari pilihan pemain, bukan dari
  /// perhitungan terdekat. Dipakai peta untuk menawarkan "kembali ke terdekat".
  bool get isPinned =>
      pinnedMosqueId != null && pinnedMosqueId != nearest?.mosque.id;

  GeofenceState copyWith({
    GeofenceStage? stage,
    GeofenceStatus? status,
    Mosque? mosque,
    PlayerPosition? position,
    List<Mosque>? mosques,
    NearestMosque? nearest,
    String? pinnedMosqueId,
    Failure? failure,
    bool clearFailure = false,
    bool clearPinned = false,
  }) =>
      GeofenceState(
        stage: stage ?? this.stage,
        status: status ?? this.status,
        mosque: mosque ?? this.mosque,
        position: position ?? this.position,
        mosques: mosques ?? this.mosques,
        nearest: nearest ?? this.nearest,
        pinnedMosqueId:
            clearPinned ? null : (pinnedMosqueId ?? this.pinnedMosqueId),
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props =>
      [stage, status, mosque, position, mosques, nearest, pinnedMosqueId, failure];
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
          : await _repository.fetchMosques(
              position: _location.lastKnown,
            );

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

  /// Membuka lokasi tertentu atas pilihan pemain, bukan hasil perhitungan.
  ///
  /// Pilihannya bertahan sampai dilepas atau sampai pemain benar-benar
  /// melangkah masuk ke area masjid lain — lihat [_resolveTarget]. Berguna
  /// untuk melihat-lihat lokasi yang belum didatangi: misi apa yang menunggu
  /// di sana, berapa titik yang tersisa, seberapa jauh perjalanannya.
  Future<void> selectMosque(String mosqueId) async {
    if (state.mosques.every((mosque) => mosque.id != mosqueId)) return;

    emit(state.copyWith(pinnedMosqueId: mosqueId));
    await _preferences.setLastMosqueId(mosqueId);

    final position = state.position ?? _location.lastKnown;
    if (position == null) return;

    // Melewati jeda otomatis: pemain baru saja mengetuk sesuatu, dan menunggu
    // delapan detik sebelum layarnya berubah akan terbaca sebagai ketukan yang
    // tidak tersampaikan.
    _lastCheckedAt = null;
    await _evaluate(position, preferredMosqueId: mosqueId);
  }

  /// Melepas pilihan manual dan kembali mengikuti lokasi terdekat.
  Future<void> followNearest() async {
    if (state.pinnedMosqueId == null) return;

    emit(state.copyWith(clearPinned: true));

    final position = state.position ?? _location.lastKnown;
    if (position == null) return;

    _lastCheckedAt = null;
    await _evaluate(position);
  }

  /// Mengambil ulang daftar lokasi beserta kemajuan pemain di masing-masing.
  ///
  /// Dipanggil daftar lokasi saat disegarkan, dan setelah sebuah penemuan —
  /// dua saat ketika angka kemajuannya memang berubah.
  Future<void> refreshMosques() async {
    try {
      final mosques = await _repository.fetchMosques(
        position: state.position ?? _location.lastKnown,
      );
      if (mosques.isEmpty) return;

      emit(state.copyWith(mosques: mosques));
    } on Object {
      // Penyegaran latar belakang yang gagal tidak boleh mengubah apa pun;
      // daftar terakhir tetap ditampilkan sampai percobaan berikutnya.
    }
  }

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

  /// Menentukan lokasi mana yang diperiksa pada evaluasi ini.
  ///
  /// Urutan kewenangannya, dari yang paling kuat:
  ///
  ///  1. **Permintaan langsung** — pemain baru saja mengetuk sebuah lokasi.
  ///  2. **Area yang benar-benar dimasuki.** Berdiri di dalam pelataran sebuah
  ///     masjid adalah pernyataan yang lebih kuat daripada pilihan yang dibuat
  ///     kemarin dari rumah, jadi pilihan manual dilepas begitu pemain masuk ke
  ///     area masjid lain. Tanpa aturan ini, seseorang yang sempat menengok
  ///     lokasi lain di daftar akan berdiri di masjid tujuannya sambil melihat
  ///     layar yang menyatakan ia berada di luar area — masjid yang salah.
  ///  3. **Pilihan manual** yang masih berlaku.
  ///  4. **Yang terdekat**, lalu yang terakhir dibuka, lalu apa pun yang ada.
  ///
  /// Mengembalikan pasangan: id yang dipakai, dan apakah pilihan manual perlu
  /// dilepas.
  ({String id, bool releasePin}) _resolveTarget(
    NearestMosque? nearest,
    String? preferredMosqueId,
  ) {
    if (preferredMosqueId != null) {
      return (id: preferredMosqueId, releasePin: false);
    }

    final pinned = state.pinnedMosqueId;
    final steppedInto = nearest != null &&
        nearest.distanceM <= nearest.mosque.radiusMeters &&
        nearest.mosque.id != pinned;

    if (pinned != null && !steppedInto) {
      return (id: pinned, releasePin: false);
    }

    final fallback = nearest?.mosque.id ??
        _preferences.lastMosqueId ??
        state.mosques.first.id;

    return (id: fallback, releasePin: pinned != null);
  }

  Future<void> _evaluate(
    PlayerPosition position, {
    String? preferredMosqueId,
  }) async {
    _lastCheckedAt = DateTime.now();

    final nearest = _nearestTo(position);
    final target = _resolveTarget(nearest, preferredMosqueId);

    try {
      final status = await _repository.checkGeofence(
        mosqueId: target.id,
        position: position,
      );

      if (status.isInside) await _preferences.setLastMosqueId(target.id);

      emit(
        state.copyWith(
          stage: status.isInside ? GeofenceStage.inside : GeofenceStage.outside,
          status: status,
          mosque: status.mosque,
          position: position,
          nearest: nearest,
          clearPinned: target.releasePin,
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
