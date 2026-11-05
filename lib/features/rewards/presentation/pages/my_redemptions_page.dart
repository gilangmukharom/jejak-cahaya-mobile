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
import 'reward_store_page.dart';

/// Semua penukaran pemain beserta kodenya — yang ditunjukkan ke petugas saat
/// mengambil hadiah.
class MyRedemptionsPage extends StatefulWidget {
  const MyRedemptionsPage({super.key});

  @override
  State<MyRedemptionsPage> createState() => _MyRedemptionsPageState();
}

class _MyRedemptionsPageState extends State<MyRedemptionsPage> {
  List<Redemption>? _items;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await sl<RewardRepository>().fetchMyRedemptions();
      if (mounted) setState(() => (_items = items, _failure = null));
    } on Object catch (error) {
      if (mounted) setState(() => _failure = FailureMapper.map(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final failure = _failure;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Penukaranku')),
      body: failure != null && items == null
          ? FailureView(failure: failure, onRetry: _load)
          : items == null
              ? const LoadingView()
              : items.isEmpty
                  ? const EmptyView(
                      icon: Icons.receipt_long_rounded,
                      title: 'Belum ada penukaran',
                      message:
                          'Hadiah yang kamu tukar di Reward Store akan muncul di sini, '
                          'lengkap dengan kode penukarannya.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _RedemptionCard(item: items[index]),
                      ),
                    ),
    );
  }
}

class _RedemptionCard extends StatelessWidget {
  const _RedemptionCard({required this.item});

  final Redemption item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (item.status) {
      RedemptionStatus.pending => AppColors.goldDark,
      RedemptionStatus.fulfilled => AppColors.success,
      RedemptionStatus.cancelled => AppColors.danger,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.rewardCategory.icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.rewardName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.status.label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${formatPoints(item.pointsSpent)} poin · '
            '${formatShortDate(item.createdAt.toLocal())}, ${formatClock(item.createdAt.toLocal())}',
            style:
                theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          if (item.status == RedemptionStatus.pending) ...[
            const SizedBox(height: 12),
            RedemptionCodeBox(code: item.code),
            if (item.howToClaim != null) ...[
              const SizedBox(height: 10),
              Text(
                item.howToClaim!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Kode ${item.code}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (item.note != null) ...[
            const SizedBox(height: 6),
            Text(
              item.note!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
