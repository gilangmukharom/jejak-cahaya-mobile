import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/challenge.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../data/reward_repository.dart';
import '../widgets/points_badge.dart';

/// Tantangan harian & mingguan — "Tantangan harian/mingguan" pada konsep.
///
/// Kemajuannya dihitung server dari penemuan dan kuis di periode berjalan
/// (WIB), jadi halaman ini cukup menampilkan dan mengklaim.
class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  List<Challenge>? _items;
  Failure? _failure;
  String? _claimingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await sl<RewardRepository>().fetchChallenges();
      if (mounted) setState(() => (_items = items, _failure = null));
    } on Object catch (error) {
      if (mounted) setState(() => _failure = FailureMapper.map(error));
    }
  }

  Future<void> _claim(Challenge challenge) async {
    setState(() => _claimingId = challenge.id);
    try {
      final points = await sl<RewardRepository>().claimChallenge(challenge.id);
      if (!mounted) return;
      showInfoSnack(context,
          '+${formatPoints(points)} NUSA POINTS dari "${challenge.title}"!');
      await context.read<AuthCubit>().refreshUser();
      await _load();
    } on Failure catch (failure) {
      if (mounted) showFailureSnack(context, failure);
    } finally {
      if (mounted) setState(() => _claimingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final failure = _failure;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Tantangan')),
      body: failure != null && items == null
          ? FailureView(failure: failure, onRetry: _load)
          : items == null
              ? const LoadingView()
              : items.isEmpty
                  ? const EmptyView(
                      icon: Icons.emoji_events_rounded,
                      title: 'Belum ada tantangan',
                      message:
                          'Tantangan harian dan mingguan akan muncul di sini.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _buildList(items),
                    ),
    );
  }

  Widget _buildList(List<Challenge> items) {
    final general = items.where((item) => !item.isCheckpoint).toList();
    final perCheckpoint = items.where((item) => item.isCheckpoint).toList();

    // Dikelompokkan per lokasi, urutan lokasi mengikuti kemunculan pertama.
    final bySite = <String, List<Challenge>>{};
    for (final item in perCheckpoint) {
      bySite.putIfAbsent(item.checkpoint!.siteName, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final period in ChallengePeriod.values)
          if (general.any((item) => item.period == period)) ...[
            _SectionTitle(
              title: 'Tantangan ${period.label}',
              endsAt:
                  general.firstWhere((item) => item.period == period).endsAt,
            ),
            for (final item in general.where((item) => item.period == period))
              _ChallengeCard(
                challenge: item,
                isClaiming: _claimingId == item.id,
                onClaim: () => _claim(item),
              ),
            const SizedBox(height: 12),
          ],
        if (bySite.isNotEmpty) ...[
          _SectionTitle(
            title: 'Jejak Hero',
            endsAt: perCheckpoint.first.endsAt,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Satu tantangan untuk setiap titik hero: pindai QR di titiknya, '
              'lalu lulus kuisnya di minggu yang sama. Hero yang sudah kamu '
              'miliki tetap bisa dikunjungi lagi tiap minggu.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.45, color: AppColors.textSecondary),
            ),
          ),
          for (final entry in bySite.entries)
            _SiteGroup(
              siteName: entry.key,
              challenges: entry.value,
              claimingId: _claimingId,
              onClaim: _claim,
            ),
        ],
      ],
    );
  }
}

/// Kelompok tantangan titik untuk satu lokasi, bisa dibuka-tutup.
///
/// Terbuka otomatis bila ada hadiah yang siap diklaim, supaya tombolnya tidak
/// tersembunyi di balik lipatan.
class _SiteGroup extends StatelessWidget {
  const _SiteGroup({
    required this.siteName,
    required this.challenges,
    required this.claimingId,
    required this.onClaim,
  });

  final String siteName;
  final List<Challenge> challenges;
  final String? claimingId;
  final void Function(Challenge) onClaim;

  @override
  Widget build(BuildContext context) {
    final done = challenges.where((item) => item.isComplete).length;
    final claimable = challenges.where((item) => item.canClaim).length;
    // Yang siap diklaim di atas, lalu yang belum selesai, lalu yang sudah diklaim.
    final sorted = [...challenges]..sort((a, b) {
        int rank(Challenge c) => c.canClaim ? 0 : (c.isClaimed ? 2 : 1);
        return rank(a).compareTo(rank(b));
      });

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: claimable > 0 ? AppColors.gold : AppColors.surfaceMuted,
          width: claimable > 0 ? 1.5 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: claimable > 0,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_rounded,
                color: AppColors.accent, size: 22),
          ),
          title: Text(
            siteName,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            claimable > 0
                ? '$claimable hadiah siap diklaim · $done/${challenges.length} selesai'
                : '$done/${challenges.length} titik selesai minggu ini',
            style: TextStyle(
              fontSize: 12,
              fontWeight: claimable > 0 ? FontWeight.w700 : FontWeight.w500,
              color: claimable > 0 ? AppColors.goldDark : AppColors.textMuted,
            ),
          ),
          children: [
            for (final item in sorted)
              _ChallengeCard(
                challenge: item,
                isClaiming: claimingId == item.id,
                onClaim: () => onClaim(item),
                dense: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.endsAt});

  final String title;
  final DateTime endsAt;

  @override
  Widget build(BuildContext context) {
    final remaining = endsAt.difference(DateTime.now());
    final label = remaining.inHours >= 24
        ? '${remaining.inDays} hari lagi'
        : remaining.inHours >= 1
            ? '${remaining.inHours} jam lagi'
            : '${remaining.inMinutes.clamp(1, 59)} menit lagi';

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          const Icon(Icons.schedule_rounded,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            'Berakhir $label',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Satu langkah tantangan titik dengan tanda centang.
class _StepLine extends StatelessWidget {
  const _StepLine({required this.done, required this.label});

  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: done ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: done ? AppColors.textPrimary : AppColors.textSecondary,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.isClaiming,
    required this.onClaim,
    this.dense = false,
  });

  final Challenge challenge;
  final bool isClaiming;
  final VoidCallback onClaim;

  /// Kartu di dalam kelompok lokasi: latar sedikit berbeda, tanpa bayangan.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget action;
    if (challenge.isClaimed) {
      action = const Chip(
        avatar: Icon(Icons.check_circle_rounded,
            size: 18, color: AppColors.success),
        label: Text('Diklaim'),
      );
    } else if (challenge.canClaim) {
      action = FilledButton(
        onPressed: isClaiming ? null : onClaim,
        style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
        child: Text(isClaiming ? 'Mengklaim…' : 'Klaim'),
      );
    } else {
      action = Text(
        '${challenge.progress}/${challenge.target}',
        style: theme.textTheme.titleSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    final steps = challenge.steps;

    return Container(
      margin: EdgeInsets.only(bottom: dense ? 8 : 10),
      padding: EdgeInsets.all(dense ? 14 : 16),
      decoration: BoxDecoration(
        color: dense ? AppColors.cream : AppColors.surface,
        borderRadius: BorderRadius.circular(dense ? 14 : 18),
        border: Border.all(
          color: challenge.canClaim ? AppColors.gold : AppColors.surfaceMuted,
          width: challenge.canClaim ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      challenge.description,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              action,
            ],
          ),
          if (steps != null) ...[
            const SizedBox(height: 10),
            _StepLine(
              done: steps.visited,
              label: 'Pindai QR di titik ${challenge.checkpoint!.code}',
            ),
            if (steps.quizPassed != null)
              _StepLine(done: steps.quizPassed!, label: 'Lulus kuisnya'),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: challenge.ratio,
              minHeight: 6,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(
                challenge.isComplete ? AppColors.success : AppColors.gold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const PointsCoin(size: 16),
              const SizedBox(width: 6),
              Text(
                '+${formatPoints(challenge.pointsReward)} NUSA POINTS',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.goldDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (challenge.xpReward > 0) ...[
                const SizedBox(width: 10),
                Text(
                  '+${challenge.xpReward} XP',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
