import '../../../../core/bloc/safe_emit.dart';
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  /// Pemain di luar area — permainan terkunci.
  outside,

  /// Izin ditolak, GPS mati, atau sinyal tidak didapat.
  locationBlocked,

  /// Gagal menghubungi server.
  error,
}

class GeofenceState extends Equatable {
  const GeofenceState({
    this.stage = GeofenceStage.initial,
    this.status,
    this.mosque,
    this.position,
    this.failure,
  });

  final GeofenceStage stage;
  final GeofenceStatus? status;
  final Mosque? mosque;
  final PlayerPosition? position;
  final Failure? failure;

  bool get isUnlocked => stage == GeofenceStage.inside;

  /// Sisa jarak menuju area masjid, dalam meter.
  double? get metersAway => status?.metersToEnter;

  GeofenceState copyWith({
    GeofenceStage? stage,
    GeofenceStatus? status,
    Mosque? mosque,
    PlayerPosition? position,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      GeofenceState(
        stage: stage ?? this.stage,
        status: status ?? this.status,
        mosque: mosque ?? this.mosque,
        position: position ?? this.position,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => [stage, status, mosque, position, failure];
}

/// Menegakkan Layer 1: aplikasi terkunci selama pemain berada di luar masjid.
///
/// Cubit ini menentukan gerbang masuk seluruh permainan. Ia terus memantau
/// posisi, sehingga layar terbuka dengan sendirinya begitu pemain melangkah
/// masuk ke area — tanpa perlu menutup dan membuka ulang aplikasi.
///
/// Pengunciannya bersifat pengalaman pengguna. Yang benar-benar mengikat adalah
/// pemeriksaan ulang di `POST /scan`; tanpa itu, keputusan di sisi client bisa
/// dilewati begitu saja.
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

  /// Jeda minimal antar pemeriksaan geofence ke server.
  ///
  /// GPS memancarkan pembaruan setiap beberapa meter; tanpa jeda ini, berjalan
  /// menyusuri halaman masjid akan menghasilkan puluhan permintaan per menit.
  /// Jeda antar pemeriksaan geofence ke server, dibedakan menurut keadaan.
  ///
  /// Kedua keadaan melayani kebutuhan yang berbeda. Saat pemain masih di luar
  /// area, pemeriksaan yang rapat itulah yang membuat gerbang terbuka sendiri
  /// beberapa detik setelah ia melangkah masuk — inti dari pengalamannya.
  /// Setelah berada di dalam, tidak ada lagi yang ditunggu: pemeriksaan hanya
  /// perlu cukup sering untuk menyadari kalau pemain berjalan keluar.
  ///
  /// Sebelumnya keduanya 8 detik, yang berarti 7,5 permintaan per menit
  /// sepanjang permainan — beban terbesar aplikasi ini, dan seluruhnya
  /// terbuang untuk menanyakan sesuatu yang jawabannya tidak berubah.
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
      final targetId =
          mosqueId ?? _preferences.lastMosqueId ?? await _firstMosqueId();

      if (targetId == null) {
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

      await _preferences.setLastMosqueId(targetId);
      await _location.ensurePermission();

      final position = await _location.getCurrentPosition();
      await _evaluate(targetId, position);

      await _startWatching(targetId);
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
    final mosqueId = state.mosque?.id ?? _preferences.lastMosqueId;
    if (mosqueId == null) {
      await initialize();
      return;
    }

    emit(state.copyWith(stage: GeofenceStage.locating, clearFailure: true));

    try {
      final position = await _location.getCurrentPosition();
      _lastCheckedAt = null;
      await _evaluate(mosqueId, position);
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

  Future<String?> _firstMosqueId() async {
    final mosques = await _repository.fetchMosques();
    return mosques.isEmpty ? null : mosques.first.id;
  }

  Future<void> _startWatching(String mosqueId) async {
    if (_positionSubscription != null) return;

    await _location.startTracking();

    _positionSubscription = _location.positionStream.listen((position) {
      final last = _lastCheckedAt;
      if (last != null && DateTime.now().difference(last) < _minCheckInterval) {
        // Posisi tetap disimpan agar radar tetap halus, hanya panggilan server
        // yang dijarangkan.
        emit(state.copyWith(position: position));
        return;
      }

      unawaited(_evaluate(mosqueId, position));
    });
  }

  Future<void> _evaluate(String mosqueId, PlayerPosition position) async {
    _lastCheckedAt = DateTime.now();

    try {
      final status = await _repository.checkGeofence(
        mosqueId: mosqueId,
        position: position,
      );

      emit(
        state.copyWith(
          stage: status.isInside ? GeofenceStage.inside : GeofenceStage.outside,
          status: status,
          mosque: status.mosque,
          position: position,
          clearFailure: true,
        ),
      );
    } on Object catch (error) {
      final failure = FailureMapper.map(error);

      // Bila sebelumnya sudah terbuka, kegagalan jaringan sesaat tidak boleh
      // mengunci ulang layar di tengah permainan.
      if (state.isUnlocked && failure is NetworkFailure) {
        emit(state.copyWith(position: position, failure: failure));
        return;
      }

      emit(
        state.copyWith(
          stage: GeofenceStage.error,
          position: position,
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
