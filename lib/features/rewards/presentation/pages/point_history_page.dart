import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/reward.dart';
import '../../../../core/utils/id_date.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/reward_repository.dart';
import '../widgets/points_badge.dart';

/// Riwayat NUSA POINTS: dari mana poin datang dan ke mana dipakai.
class PointHistoryPage extends StatefulWidget {
  const PointHistoryPage({super.key});

  @override
  State<PointHistoryPage> createState() => _PointHistoryPageState();
}

class _PointHistoryPageState extends State<PointHistoryPage> {
  ({int balance, List<PointEntry> entries})? _data;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await sl<RewardRepository>().fetchPointHistory();
      if (mounted) setState(() => (_data = data, _failure = null));
    } on Object catch (error) {
      if (mounted) setState(() => _failure = FailureMapper.map(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final failure = _failure;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Riwayat NUSA POINTS')),
      body: failure != null && data == null
          ? FailureView(failure: failure, onRetry: _load)
          : data == null
              ? const LoadingView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _BalanceCard(balance: data.balance),
                      const SizedBox(height: 16),
                      if (data.entries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: EmptyView(
                            icon: Icons.stars_rounded,
                            title: 'Belum ada poin',
                            message:
                                'Temukan hero pertamamu di lokasi bersejarah untuk '
                                'mulai mengumpulkan NUSA POINTS.',
                          ),
                        )
                      else
                        for (final entry in data.entries)
                          _EntryTile(entry: entry),
                    ],
                  ),
                ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const PointsCoin(size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo saat ini',
                  style: TextStyle(
                      color: AppColors.textOnDark.withValues(alpha: 0.7),
                      fontSize: 12),
                ),
                Text(
                  '${formatPoints(balance)} NUSA POINTS',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final PointEntry entry;

  static String _label(String source) => switch (source) {
        'DISCOVERY' => 'Menemukan hero',
        'QUIZ' => 'Kuis sejarah',
        'MISSION' => 'Misi selesai',
        'LOCATION_VISIT' => 'Kunjungan lokasi mitra',
        'REDEMPTION' => 'Ditukar di Reward Store',
        'REFUND' => 'Pengembalian penukaran',
        _ => 'Penyesuaian',
      };

  static IconData _icon(String source) => switch (source) {
        'DISCOVERY' => Icons.person_search_rounded,
        'QUIZ' => Icons.quiz_rounded,
        'MISSION' => Icons.flag_rounded,
        'LOCATION_VISIT' => Icons.place_rounded,
        'REDEMPTION' => Icons.redeem_rounded,
        'REFUND' => Icons.undo_rounded,
        _ => Icons.tune_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = entry.amount >= 0;
    final color = positive ? AppColors.success : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(_icon(entry.source), color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.note ?? _label(entry.source),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${_label(entry.source)} · ${formatShortDate(entry.createdAt.toLocal())}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Text(
              '${positive ? '+' : '−'}${formatPoints(entry.amount.abs())}',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
