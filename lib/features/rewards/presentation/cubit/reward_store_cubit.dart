import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/safe_emit.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/reward.dart';
import '../../data/reward_repository.dart';

class RewardStoreState extends Equatable {
  const RewardStoreState({
    this.isLoading = false,
    this.balance = 0,
    this.rewards = const [],
    this.category,
    this.redeemingId,
    this.failure,
  });

  final bool isLoading;
  final int balance;
  final List<Reward> rewards;

  /// Null = semua kategori.
  final RewardCategory? category;

  /// Hadiah yang sedang diproses penukarannya.
  final String? redeemingId;
  final Failure? failure;

  List<Reward> get visibleRewards => category == null
      ? rewards
      : rewards.where((reward) => reward.category == category).toList();

  /// Kategori yang benar-benar punya hadiah — chip kosong hanya membingungkan.
  List<RewardCategory> get availableCategories => RewardCategory.values
      .where((category) => rewards.any((reward) => reward.category == category))
      .toList();

  RewardStoreState copyWith({
    bool? isLoading,
    int? balance,
    List<Reward>? rewards,
    RewardCategory? category,
    String? redeemingId,
    Failure? failure,
    bool clearCategory = false,
    bool clearRedeeming = false,
    bool clearFailure = false,
  }) =>
      RewardStoreState(
        isLoading: isLoading ?? this.isLoading,
        balance: balance ?? this.balance,
        rewards: rewards ?? this.rewards,
        category: clearCategory ? null : (category ?? this.category),
        redeemingId: clearRedeeming ? null : (redeemingId ?? this.redeemingId),
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props =>
      [isLoading, balance, rewards, category, redeemingId, failure];
}

/// Katalog Reward Store dan penukarannya.
class RewardStoreCubit extends Cubit<RewardStoreState>
    with SafeEmit<RewardStoreState> {
  RewardStoreCubit(this._repository) : super(const RewardStoreState());

  final RewardRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));
    try {
      final catalog = await _repository.fetchCatalog();
      emit(state.copyWith(
        isLoading: false,
        balance: catalog.balance,
        rewards: catalog.rewards,
      ));
    } on Object catch (error) {
      emit(state.copyWith(isLoading: false, failure: FailureMapper.map(error)));
    }
  }

  void selectCategory(RewardCategory? category) => emit(
        category == null
            ? state.copyWith(clearCategory: true)
            : state.copyWith(category: category),
      );

  /// Menukar [reward]. Mengembalikan penukaran yang berhasil, atau melempar
  /// [Failure] dengan pesan dari server (poin kurang, stok habis, …).
  ///
  /// Katalog dimuat ulang setelahnya — berhasil atau gagal — karena stok dan
  /// saldo yang tampil bisa saja sudah berubah sejak layar dibuka.
  Future<Redemption> redeem(Reward reward) async {
    emit(state.copyWith(redeemingId: reward.id));
    try {
      final result = await _repository.redeem(reward.id);
      emit(state.copyWith(balance: result.balance, clearRedeeming: true));
      await load();
      return result.redemption;
    } on Object catch (error) {
      emit(state.copyWith(clearRedeeming: true));
      await load();
      throw FailureMapper.map(error);
    }
  }
}
