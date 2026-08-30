import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/checkpoint.dart';
import '../../../../core/models/mission.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/scan_result_holder.dart';
import '../../data/game_repository.dart';

class ExploreState extends Equatable {
  const ExploreState({
    this.isLoading = false,
    this.checkpoints = const [],
    this.activeMission,
    this.position,
    this.failure,
  });

  final bool isLoading;
  final List<Checkpoint> checkpoints;
  final Mission? activeMission;
  final PlayerPosition? position;
  final Failure? failure;

  /// Checkpoint yang belum ditemukan, diurutkan dari yang terdekat.
  ///
  /// Inilah yang menggerakkan radar: pemain hanya perlu tahu titik terdekat
  /// berikutnya, bukan seluruh daftar.
  List<Checkpoint> get pendingNearby {
    final pending = checkpoints.where((item) => !item.isDiscovered).toList()
      ..sort(
        (a, b) => (a.distanceM ?? double.infinity)
            .compareTo(b.distanceM ?? double.infinity),
      );
    return pending;
  }

  Checkpoint? get nearestPending =>
      pendingNearby.isEmpty ? null : pendingNearby.first;

  int get discoveredCount =>
      checkpoints.where((item) => item.isDiscovered).length;

  bool get isAllDiscovered =>
      checkpoints.isNotEmpty && discoveredCount == checkpoints.length;

  ExploreState copyWith({
    bool? isLoading,
    List<Checkpoint>? checkpoints,
    Mission? activeMission,
    PlayerPosition? position,
    Failure? failure,
    bool clearFailure = false,
    bool clearMission = false,
  }) =>
      ExploreState(
        isLoading: isLoading ?? this.isLoading,
        checkpoints: checkpoints ?? this.checkpoints,
        activeMission:
            clearMission ? null : (activeMission ?? this.activeMission),
        position: position ?? this.position,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props =>
      [isLoading, checkpoints, activeMission, position, failure];
}

/// Mengendalikan layar peta & radar: checkpoint di sekitar dan misi yang aktif.
class ExploreCubit extends Cubit<ExploreState> {
  ExploreCubit({
    required GameRepository repository,
    required LocationService locationService,
    required ScanResultHolder scanResults,
  })  : _repository = repository,
        _location = locationService,
        super(const ExploreState()) {
    // Tab peta tetap hidup selama pemain memindai, jadi kembali ke sini tidak
    // membangun ulang apa pun. Tanpa langganan ini, checkpoint yang barusan
    // ditemukan masih tampil belum ditemukan dan hitungan progresnya tidak
    // pernah bertambah sampai aplikasi dibuka ulang.
    _discoverySubscription = scanResults.onDiscovery.listen((_) {
      unawaited(refreshAfterDiscovery());
    });
  }

  final GameRepository _repository;
  final LocationService _location;

  StreamSubscription<PlayerPosition>? _positionSubscription;
  StreamSubscription<void>? _discoverySubscription;
  String? _mosqueId;

  /// Jeda antar pengambilan ulang jarak checkpoint dari server.
  ///
  /// Jarak dihitung ulang secara lokal pada setiap pembaruan GPS agar radar
  /// terasa hidup; server hanya dihubungi sesekali untuk menyelaraskan status
  /// penemuan dan menghindari pergeseran perhitungan.
  static const Duration _syncInterval = Duration(seconds: 20);
  DateTime? _lastSyncAt;

  Future<void> load(String mosqueId) async {
    _mosqueId = mosqueId;
    emit(state.copyWith(isLoading: true, clearFailure: true));

    try {
      final position =
          _location.lastKnown ?? await _location.getCurrentPosition();

      final (checkpoints, activeMission) = await (
        _repository.fetchCheckpoints(mosqueId: mosqueId, position: position),
        _repository.fetchActiveMission(mosqueId),
      ).wait;

      _lastSyncAt = DateTime.now();

      emit(
        state.copyWith(
          isLoading: false,
          checkpoints: checkpoints,
          activeMission: activeMission,
          position: position,
          clearFailure: true,
          clearMission: activeMission == null,
        ),
      );

      await _startWatching();
    } on Object catch (error) {
      emit(state.copyWith(isLoading: false, failure: FailureMapper.map(error)));
    }
  }

  /// Menyegarkan setelah sebuah penemuan, agar checkpoint yang baru dipindai
  /// langsung berubah status dan progres misi ikut diperbarui.
  Future<void> refreshAfterDiscovery() async {
    final mosqueId = _mosqueId;
    if (mosqueId == null) return;

    _lastSyncAt = null;
    await _syncFromServer(_location.lastKnown);
  }

  Future<void> _startWatching() async {
    if (_positionSubscription != null) return;

    _positionSubscription = _location.positionStream.listen((position) {
      _recomputeDistances(position);

      final last = _lastSyncAt;
      if (last == null || DateTime.now().difference(last) >= _syncInterval) {
        unawaited(_syncFromServer(position));
      }
    });
  }

  /// Menghitung ulang jarak & bearing secara lokal.
  ///
  /// Rumusnya identik dengan yang dipakai server, sehingga nilai yang muncul di
  /// layar tidak akan berbeda dari yang dipakai untuk menilai scan.
  void _recomputeDistances(PlayerPosition position) {
    if (state.checkpoints.isEmpty) {
      emit(state.copyWith(position: position));
      return;
    }

    final updated = state.checkpoints.map((checkpoint) {
      final distance = LocationService.distanceMeters(
        fromLat: position.latitude,
        fromLon: position.longitude,
        toLat: checkpoint.latitude,
        toLon: checkpoint.longitude,
      );

      final bearing = LocationService.bearingDegrees(
        fromLat: position.latitude,
        fromLon: position.longitude,
        toLat: checkpoint.latitude,
        toLon: checkpoint.longitude,
      );

      return Checkpoint(
        id: checkpoint.id,
        code: checkpoint.code,
        name: checkpoint.name,
        latitude: checkpoint.latitude,
        longitude: checkpoint.longitude,
        radiusMeters: checkpoint.radiusMeters,
        isDiscovered: checkpoint.isDiscovered,
        collectiblePreview: checkpoint.collectiblePreview,
        hint: checkpoint.hint,
        distanceM: (distance * 10).round() / 10,
        bearingDeg: (bearing * 10).round() / 10,
        isInRange: distance <= checkpoint.radiusMeters,
      );
    }).toList(growable: false);

    emit(state.copyWith(checkpoints: updated, position: position));
  }

  Future<void> _syncFromServer(PlayerPosition? position) async {
    final mosqueId = _mosqueId;
    if (mosqueId == null) return;

    _lastSyncAt = DateTime.now();

    try {
      final (checkpoints, activeMission) = await (
        _repository.fetchCheckpoints(mosqueId: mosqueId, position: position),
        _repository.fetchActiveMission(mosqueId),
      ).wait;

      emit(
        state.copyWith(
          checkpoints: checkpoints,
          activeMission: activeMission,
          clearFailure: true,
          clearMission: activeMission == null,
        ),
      );
    } on Object {
      // Penyegaran latar belakang yang gagal tidak boleh mengganggu layar;
      // data terakhir tetap ditampilkan sampai percobaan berikutnya.
    }
  }

  @override
  Future<void> close() async {
    await _positionSubscription?.cancel();
    await _discoverySubscription?.cancel();
    return super.close();
  }
}
