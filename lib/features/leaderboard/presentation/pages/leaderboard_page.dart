import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/leaderboard_entry.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../game/data/game_repository.dart';
import '../cubit/leaderboard_cubit.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LeaderboardCubit>(
      create: (_) => LeaderboardCubit(sl<GameRepository>())..load(),
      child: const _LeaderboardView(),
    );
  }
}

class _LeaderboardView extends StatelessWidget {
  const _LeaderboardView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Papan Peringkat'),
      ),
      body: BlocBuilder<LeaderboardCubit, LeaderboardState>(
        builder: (context, state) {
          return Column(
            children: [
              _PeriodSelector(selected: state.period),
              Expanded(child: _LeaderboardBody(state: state)),
              // Baris "Anda" ditempelkan di bawah hanya bila pemain tidak
              // terlihat di daftar — kalau sudah terlihat, mengulangnya justru
              // membingungkan.
              if (state.myRank != null && !state.isMyRankVisible)
                _StickyMyRank(entry: state.myRank!),
            ],
          );
        },
      ),
    );
  }
}

class _LeaderboardBody extends StatelessWidget {
  const _LeaderboardBody({required this.state});

  final LeaderboardState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.entries.isEmpty) {
      return const LoadingView();
    }

    final failure = state.failure;
    if (failure != null && state.entries.isEmpty) {
      return FailureView(
        failure: failure,
        onRetry: () => context.read<LeaderboardCubit>().load(),
      );
    }

    if (state.entries.isEmpty) {
      return const EmptyView(
        icon: Icons.leaderboard_outlined,
        title: 'Belum ada peringkat',
        message: 'Jadilah yang pertama mengumpulkan XP pada periode ini!',
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<LeaderboardCubit>().load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: state.entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) =>
            _LeaderboardRow(entry: state.entries[index]),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected});

  final LeaderboardPeriod selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SegmentedButton<LeaderboardPeriod>(
        segments: [
          for (final period in LeaderboardPeriod.values)
            ButtonSegment<LeaderboardPeriod>(
              value: period,
              label: Text(period.label, style: const TextStyle(fontSize: 12)),
            ),
        ],
        selected: {selected},
        onSelectionChanged: (selection) =>
            context.read<LeaderboardCubit>().changePeriod(selection.first),
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final LeaderboardEntry entry;

  /// Warna medali untuk tiga besar; sisanya memakai warna netral.
  Color get _rankColor => switch (entry.rank) {
        1 => AppColors.gold,
        2 => const Color(0xFF9DA8A3),
        3 => const Color(0xFFB07A45),
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = entry.isCurrentUser;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withValues(alpha: 0.07)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? AppColors.primary : AppColors.surfaceMuted,
          width: isMe ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: entry.isPodium
                ? Icon(Icons.emoji_events_rounded, color: _rankColor, size: 26)
                : Text(
                    '${entry.rank}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _rankColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              entry.fullName.isNotEmpty
                  ? entry.fullName.substring(0, 1).toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${entry.fullName} (Anda)' : entry.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Level ${entry.level} · ${entry.discoveryCount} tokoh',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '${entry.xp} XP',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyMyRank extends StatelessWidget {
  const _StickyMyRank({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceMuted)),
      ),
      child: SafeArea(
        top: false,
        child: _LeaderboardRow(entry: entry),
      ),
    );
  }
}
