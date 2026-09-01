import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/safe_emit.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/achievement.dart';
import '../../../../core/models/user.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../game/data/game_repository.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.isLoading = false,
    this.stats,
    this.achievements = const [],
    this.failure,
  });

  final bool isLoading;
  final PlayerStats? stats;
  final List<Achievement> achievements;
  final Failure? failure;

  List<Achievement> get unlockedAchievements =>
      achievements.where((item) => item.isUnlocked).toList(growable: false);

  /// Pencapaian yang belum terbuka, diurutkan dari yang paling dekat tercapai —
  /// pemain melihat target yang realistis lebih dulu, bukan yang masih jauh.
  List<Achievement> get nextAchievements {
    final locked = achievements.where((item) => !item.isUnlocked).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
    return locked;
  }

  ProfileState copyWith({
    bool? isLoading,
    PlayerStats? stats,
    List<Achievement>? achievements,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      ProfileState(
        isLoading: isLoading ?? this.isLoading,
        stats: stats ?? this.stats,
        achievements: achievements ?? this.achievements,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => [isLoading, stats, achievements, failure];
}

class ProfileCubit extends Cubit<ProfileState> with SafeEmit<ProfileState> {
  ProfileCubit({
    required AuthRepository authRepository,
    required GameRepository gameRepository,
  })  : _auth = authRepository,
        _game = gameRepository,
        super(const ProfileState());

  final AuthRepository _auth;
  final GameRepository _game;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));

    try {
      final (stats, achievements) = await (
        _auth.fetchStats(),
        _game.fetchAchievements(),
      ).wait;

      emit(
        state.copyWith(
          isLoading: false,
          stats: stats,
          achievements: achievements,
          clearFailure: true,
        ),
      );
    } on Object catch (error) {
      emit(state.copyWith(isLoading: false, failure: FailureMapper.map(error)));
    }
  }
}
