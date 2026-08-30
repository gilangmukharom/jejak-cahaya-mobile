import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/collectible.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/services/scan_result_holder.dart';
import '../../../game/data/game_repository.dart';

class CollectionState extends Equatable {
  const CollectionState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.entries = const [],
    this.progress = CollectionProgress.empty,
    this.categoryFilter,
    this.hasMore = false,
    this.failure,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final List<CollectionEntry> entries;
  final CollectionProgress progress;
  final CollectibleCategory? categoryFilter;
  final bool hasMore;
  final Failure? failure;

  bool get isEmpty => !isLoading && entries.isEmpty;

  CollectionState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<CollectionEntry>? entries,
    CollectionProgress? progress,
    CollectibleCategory? categoryFilter,
    bool? hasMore,
    Failure? failure,
    bool clearFailure = false,
    bool clearFilter = false,
  }) =>
      CollectionState(
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        entries: entries ?? this.entries,
        progress: progress ?? this.progress,
        categoryFilter:
            clearFilter ? null : (categoryFilter ?? this.categoryFilter),
        hasMore: hasMore ?? this.hasMore,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => [
        isLoading,
        isLoadingMore,
        entries,
        progress,
        categoryFilter,
        hasMore,
        failure
      ];
}

/// Galeri koleksi pemain, dengan paginasi dan penyaringan per kategori.
class CollectionCubit extends Cubit<CollectionState> {
  CollectionCubit(this._repository, ScanResultHolder scanResults)
      : super(const CollectionState()) {
    // Tab koleksi mempertahankan state-nya, jadi tokoh yang baru ditemukan
    // tidak akan muncul sampai pemain menarik-untuk-menyegarkan sendiri.
    _discoverySubscription = scanResults.onDiscovery.listen((_) {
      unawaited(refresh());
    });
  }

  final GameRepository _repository;

  StreamSubscription<void>? _discoverySubscription;
  int _page = 1;

  Future<void> load({CollectibleCategory? category}) async {
    _page = 1;
    emit(
      state.copyWith(
        isLoading: true,
        clearFailure: true,
        categoryFilter: category,
        clearFilter: category == null,
      ),
    );

    try {
      // Record `.wait` menjalankan keduanya bersamaan sambil mempertahankan
      // tipe masing-masing — tidak seperti `Future.wait` pada List, yang
      // meratakan hasilnya menjadi satu tipe gabungan.
      final (page, progress) = await (
        _repository.fetchCollection(page: 1, category: category?.value),
        _repository.fetchCollectionProgress(),
      ).wait;

      emit(
        state.copyWith(
          isLoading: false,
          entries: page.items,
          progress: progress,
          hasMore: page.hasMore,
          clearFailure: true,
        ),
      );
    } on Object catch (error) {
      emit(state.copyWith(isLoading: false, failure: FailureMapper.map(error)));
    }
  }

  /// Memuat halaman berikutnya saat pengguna menggulir ke bawah.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final page = await _repository.fetchCollection(
        page: _page + 1,
        category: state.categoryFilter?.value,
      );

      _page += 1;

      emit(
        state.copyWith(
          isLoadingMore: false,
          entries: [...state.entries, ...page.items],
          hasMore: page.hasMore,
        ),
      );
    } on Object catch (error) {
      emit(state.copyWith(
          isLoadingMore: false, failure: FailureMapper.map(error)));
    }
  }

  Future<void> filterBy(CollectibleCategory? category) =>
      load(category: category);

  Future<void> refresh() => load(category: state.categoryFilter);

  @override
  Future<void> close() async {
    await _discoverySubscription?.cancel();
    return super.close();
  }
}
