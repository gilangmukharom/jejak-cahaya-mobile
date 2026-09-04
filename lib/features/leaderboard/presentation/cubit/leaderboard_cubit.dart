import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/safe_emit.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/leaderboard_entry.dart';
import '../../../game/data/game_repository.dart';

class LeaderboardState extends Equatable {
  const LeaderboardState({
    this.isLoading = false,
    this.entries = const [],
    this.period = LeaderboardPeriod.all,
    this.myRank,
    this.failure,
  });

  final bool isLoading;
  final List<LeaderboardEntry> entries;
  final LeaderboardPeriod period;

  /// Peringkat pemain sendiri, ditampilkan menempel di bawah daftar agar tetap
  /// terlihat meski posisinya jauh di luar halaman pertama.
  final LeaderboardEntry? myRank;

  final Failure? failure;

  /// True bila pemain sudah muncul di daftar yang tampil, sehingga baris
  /// "Anda" di bawah tidak perlu diduplikasi.
  bool get isMyRankVisible =>
      myRank != null && entries.any((entry) => entry.userId == myRank!.userId);

  LeaderboardState copyWith({
    bool? isLoading,
    List<LeaderboardEntry>? entries,
    LeaderboardPeriod? period,
    LeaderboardEntry? myRank,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      LeaderboardState(
        isLoading: isLoading ?? this.isLoading,
        entries: entries ?? this.entries,
        period: period ?? this.period,
        myRank: myRank ?? this.myRank,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => [isLoading, entries, period, myRank, failure];
}

class LeaderboardCubit extends Cubit<LeaderboardState>
    with SafeEmit<LeaderboardState> {
  LeaderboardCubit(this._repository) : super(const LeaderboardState());

  final GameRepository _repository;

  Future<void> load([LeaderboardPeriod? period]) async {
    final target = period ?? state.period;
    emit(state.copyWith(isLoading: true, period: target, clearFailure: true));

    try {
      final (page, myRank) = await (
        _repository.fetchLeaderboard(period: target, limit: 50),
        _repository.fetchMyRank(),
      ).wait;

      emit(
        state.copyWith(
          isLoading: false,
          entries: page.items,
          myRank: myRank,
          clearFailure: true,
        ),
      );
    } on Object catch (error) {
      emit(state.copyWith(isLoading: false, failure: FailureMapper.map(error)));
    }
  }

  Future<void> changePeriod(LeaderboardPeriod period) => load(period);
}
