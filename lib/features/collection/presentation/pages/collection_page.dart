import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/collectible.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/services/scan_result_holder.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../game/data/game_repository.dart';
import '../cubit/collection_cubit.dart';

/// Galeri tokoh & artefak yang sudah ditemukan pemain.
class CollectionPage extends StatelessWidget {
  const CollectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollectionCubit>(
      create: (_) =>
          CollectionCubit(sl<GameRepository>(), sl<ScanResultHolder>())..load(),
      child: const _CollectionView(),
    );
  }
}

class _CollectionView extends StatefulWidget {
  const _CollectionView();

  @override
  State<_CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<_CollectionView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Memuat halaman berikutnya sebelum pengguna benar-benar mencapai dasar,
  /// agar gulirannya tidak tersendat menunggu jaringan.
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      context.read<CollectionCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Koleksi Saya')),
      body: BlocBuilder<CollectionCubit, CollectionState>(
        builder: (context, state) {
          if (state.isLoading && state.entries.isEmpty) {
            return const LoadingView(message: 'Memuat koleksi…');
          }

          final failure = state.failure;
          if (failure != null && state.entries.isEmpty) {
            return FailureView(
              failure: failure,
              onRetry: () => context.read<CollectionCubit>().refresh(),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<CollectionCubit>().refresh(),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                    child: _ProgressCard(progress: state.progress)),
                SliverToBoxAdapter(
                  child: _CategoryFilter(selected: state.categoryFilter),
                ),
                if (state.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      icon: Icons.auto_stories_outlined,
                      title: 'Koleksi masih kosong',
                      message: state.categoryFilter == null
                          ? 'Datangi checkpoint di area masjid lalu pindai QR untuk menemukan tokoh pertamamu.'
                          : 'Belum ada tokoh dari kategori ini di koleksimu.',
                      action: state.categoryFilter == null
                          ? FilledButton.icon(
                              onPressed: () => context.push(AppRoutes.scanner),
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: const Text('Mulai Memindai'),
                            )
                          : null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.68,
                      ),
                      itemCount: state.entries.length,
                      itemBuilder: (context, index) =>
                          _CollectionCard(entry: state.entries[index]),
                    ),
                  ),
                if (state.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final CollectionProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${progress.owned}',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ ${progress.total} tokoh & artefak',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          XpProgressBar(
            progress: progress.total > 0 ? progress.owned / progress.total : 0,
            label:
                'Kelengkapan koleksi ${progress.completionRate.toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({this.selected});

  final CollectibleCategory? selected;

  static const List<CollectibleCategory> _categories = [
    CollectibleCategory.companion,
    CollectibleCategory.scholar,
    CollectibleCategory.explorer,
    CollectibleCategory.leader,
    CollectibleCategory.nusantara,
    CollectibleCategory.artifact,
  ];

  @override
  Widget build(BuildContext context) {
    // 52 dp, bukan 44: ChoiceChip menerapkan target sentuh minimum 48 dp
    // (materialTapTargetSize.padded), sehingga baris yang lebih pendek
    // menghasilkan garis overflow.
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChipItem(
            label: 'Semua',
            isSelected: selected == null,
            onTap: () => context.read<CollectionCubit>().filterBy(null),
          ),
          for (final category in _categories) ...[
            const SizedBox(width: 8),
            _FilterChipItem(
              label: category.label,
              isSelected: selected == category,
              onTap: () => context.read<CollectionCubit>().filterBy(category),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      showCheckmark: false,
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.entry});

  final CollectionEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collectible = entry.collectible;
    final rarityValue = collectible.rarity.value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.collectibleDetail(collectible.slug)),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            gradient: AppColors.rarityGradient(rarityValue),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          collectible.type == CollectibleType.artifact
                              ? Icons.museum_rounded
                              : Icons.person_rounded,
                          size: 56,
                          color: AppColors.rarity(rarityValue)
                              .withValues(alpha: 0.85),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: RarityBadge(rarity: rarityValue, compact: true),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collectible.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.textOnDark,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        collectible.era ?? collectible.category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textOnDark.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
