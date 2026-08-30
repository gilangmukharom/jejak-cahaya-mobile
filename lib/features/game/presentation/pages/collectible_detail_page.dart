import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/collectible.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/game_repository.dart';

/// Halaman kisah lengkap satu tokoh atau artefak.
///
/// Untuk item yang belum ditemukan, backend tidak mengirim `story`; halaman ini
/// menampilkan keadaan terkunci alih-alih badan teks kosong.
class CollectibleDetailPage extends StatefulWidget {
  const CollectibleDetailPage({required this.idOrSlug, super.key});

  final String idOrSlug;

  @override
  State<CollectibleDetailPage> createState() => _CollectibleDetailPageState();
}

class _CollectibleDetailPageState extends State<CollectibleDetailPage> {
  Collectible? _collectible;
  Failure? _failure;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });

    try {
      final collectible =
          await sl<GameRepository>().fetchCollectible(widget.idOrSlug);
      if (!mounted) return;
      setState(() {
        _collectible = collectible;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = FailureMapper.map(error);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingView(message: 'Memuat kisah…'));
    }

    final failure = _failure;
    if (failure != null) {
      return Scaffold(
        appBar: AppBar(),
        body: FailureView(failure: failure, onRetry: _load),
      );
    }

    final collectible = _collectible!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _DetailHeader(collectible: collectible),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            sliver: SliverList.list(
              children: [
                _MetaRow(collectible: collectible),
                const SizedBox(height: 24),
                Text(
                  collectible.summary,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                ),
                const SizedBox(height: 28),
                if (collectible.isDiscovered && collectible.story != null)
                  _StoryBody(story: collectible.story!)
                else
                  const _LockedStory(),
                const SizedBox(height: 32),
                // Quiz terbuka begitu tokohnya ditemukan. Tautan ini penting:
                // tanpanya, satu-satunya jalan menuju quiz hanyalah layar hasil
                // scan — sekali terlewat, quiz-nya tidak bisa dikerjakan lagi.
                if (collectible.isDiscovered) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push(
                        AppRoutes.quizByCollectible(collectible.id),
                      ),
                      icon: const Icon(Icons.quiz_rounded, size: 20),
                      label: const Text('Kerjakan Quiz'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.explore),
                      icon: const Icon(Icons.explore_rounded, size: 20),
                      label: const Text('Lanjut Menjelajah'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.collectible});

  final Collectible collectible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rarityValue = collectible.rarity.value;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.primaryDark,
      foregroundColor: AppColors.textOnDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.rarity(rarityValue),
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    collectible.type == CollectibleType.artifact
                        ? Icons.museum_rounded
                        : Icons.person_rounded,
                    size: 56,
                    color: AppColors.rarity(rarityValue),
                  ),
                ),
                const SizedBox(height: 16),
                RarityBadge(rarity: rarityValue),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    collectible.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (collectible.title != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      collectible.title!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.gold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.collectible});

  final Collectible collectible;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (collectible.era != null)
          _MetaChip(icon: Icons.schedule_rounded, label: collectible.era!),
        if (collectible.region != null)
          _MetaChip(icon: Icons.public_rounded, label: collectible.region!),
        _MetaChip(
          icon: Icons.category_rounded,
          label: collectible.category.label,
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StoryBody extends StatelessWidget {
  const _StoryBody({required this.story});

  final String story;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Naskah kisah memakai baris kosong sebagai pemisah paragraf; dipecah di
    // sini agar tiap paragraf mendapat jarak yang nyaman dibaca di ponsel.
    final paragraphs = story
        .split(RegExp(r'\n\s*\n'))
        .where((paragraph) => paragraph.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kisahnya',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        for (final paragraph in paragraphs) ...[
          Text(
            paragraph.trim(),
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.75),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _LockedStory extends StatelessWidget {
  const _LockedStory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 40,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'Kisah Masih Terkunci',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Temukan tokoh ini di checkpoint masjid untuk membuka kisah lengkapnya.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
