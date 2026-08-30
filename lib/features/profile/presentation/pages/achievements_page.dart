import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/achievement.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../game/data/game_repository.dart';
import '../cubit/profile_cubit.dart';

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>(
      create: (_) => ProfileCubit(
        authRepository: sl<AuthRepository>(),
        gameRepository: sl<GameRepository>(),
      )..load(),
      child: const _AchievementsView(),
    );
  }
}

class _AchievementsView extends StatelessWidget {
  const _AchievementsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Pencapaian'),
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (state.isLoading && state.achievements.isEmpty) {
            return const LoadingView();
          }

          final failure = state.failure;
          if (failure != null && state.achievements.isEmpty) {
            return FailureView(
              failure: failure,
              onRetry: () => context.read<ProfileCubit>().load(),
            );
          }

          final unlocked = state.unlockedAchievements;
          final locked = state.nextAchievements;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SummaryBar(
                unlocked: unlocked.length,
                total: state.achievements.length,
              ),
              if (unlocked.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionTitle(title: 'Sudah Terbuka (${unlocked.length})'),
                const SizedBox(height: 12),
                for (final achievement in unlocked) ...[
                  _AchievementCard(achievement: achievement),
                  const SizedBox(height: 10),
                ],
              ],
              if (locked.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionTitle(title: 'Sedang Diperjuangkan (${locked.length})'),
                const SizedBox(height: 12),
                for (final achievement in locked) ...[
                  _AchievementCard(achievement: achievement),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.unlocked, required this.total});

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.military_tech_rounded,
            size: 40,
            color: AppColors.gold,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$unlocked dari $total pencapaian',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textOnDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                XpProgressBar(
                  progress: total > 0 ? unlocked / total : 0,
                  label: 'Teruslah menjelajah untuk membuka sisanya',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = achievement.isUnlocked;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked
              ? AppColors.gold.withValues(alpha: 0.45)
              : AppColors.surfaceMuted,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: unlocked
                  ? AppColors.gold.withValues(alpha: 0.16)
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              unlocked
                  ? Icons.emoji_events_rounded
                  : Icons.lock_outline_rounded,
              color: unlocked ? AppColors.goldDark : AppColors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: unlocked
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '+${achievement.xpReward} XP',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.goldDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                // Bilah kemajuan hanya relevan sebelum terbuka; setelahnya ia
                // selalu penuh dan hanya menambah kebisingan visual.
                if (!unlocked) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: achievement.progress,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${achievement.currentValue}/${achievement.threshold}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
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
