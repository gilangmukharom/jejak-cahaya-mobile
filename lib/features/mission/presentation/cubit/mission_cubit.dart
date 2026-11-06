import '../../../../core/bloc/safe_emit.dart';
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/mission.dart';
import '../../../../core/services/scan_result_holder.dart';
import '../../../game/data/game_repository.dart';

class MissionState extends Equatable {
  const MissionState({
    this.isLoading = false,
    this.missions = const [],
    this.detail,
    this.failure,
  });

  final bool isLoading;
  final List<Mission> missions;
  final MissionDetail? detail;
  final Failure? failure;

  Mission? get activeMission {
    for (final mission in missions) {
      if (mission.status.value == 'IN_PROGRESS') return mission;
    }
    return null;
  }

  int get completedCount =>
      missions.where((mission) => mission.status.isCompleted).length;

  MissionState copyWith({
    bool? isLoading,
    List<Mission>? missions,
    MissionDetail? detail,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      MissionState(
        isLoading: isLoading ?? this.isLoading,
        missions: missions ?? this.missions,
        detail: detail ?? this.detail,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => [isLoading, missions, detail, failure];
}

class MissionCubit extends Cubit<MissionState> with SafeEmit<MissionState> {
  MissionCubit(this._repository, ScanResultHolder scanResults)
      : super(const MissionState()) {
    // Sebuah penemuan bisa menuntaskan misi dan membuka misi berikutnya.
    // Tanpa langganan ini, daftar misi masih menampilkan status lama karena
    // tab-nya mempertahankan state.
    _discoverySubscription = scanResults.onDiscovery.listen((_) {
      final mosqueId = _lastMosqueId;
      final missionId = _lastMissionId;
      if (mosqueId != null) unawaited(loadMissions(mosqueId));
      if (missionId != null) unawaited(loadDetail(missionId));
    });
  }

  final GameRepository _repository;

  StreamSubscription<void>? _discoverySubscription;
  String? _lastMosqueId;
  String? _lastMissionId;

  Future<void> loadMissions(String mosqueId) async {
    _lastMosqueId = mosqueId;
    emit(state.copyWith(isLoading: true, clearFailure: true));

    try {
      final missions = await _repository.fetchMissions(mosqueId);
      emit(state.copyWith(
          isLoading: false, missions: missions, clearFailure: true));
    } on Object catch (error) {
      emit(state.copyWith(isLoading: false, failure: FailureMapper.map(error)));
    }
  }

  Future<void> loadDetail(String missionId) async {
    _lastMissionId = missionId;
    emit(state.copyWith(isLoading: true, clearFailure: true));

    try {
      final detail = await _repository.fetchMissionDetail(missionId);
      emit(
          state.copyWith(isLoading: false, detail: detail, clearFailure: true));
    } on Object catch (error) {
      emit(state.copyWith(isLoading: false, failure: FailureMapper.map(error)));
    }
  }

  @override
  Future<void> close() async {
    await _discoverySubscription?.cancel();
    return super.close();
  }
}
