import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/reward.dart';
import '../../../../core/utils/asset_url.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../game/presentation/pages/home_shell.dart';
import '../../data/reward_repository.dart';
import '../cubit/reward_store_cubit.dart';
import '../widgets/points_badge.dart';

/// Reward Store: tukar NUSA POINTS dengan merchandise, voucher, tiket, dan
/// item digital.
///
/// Sesuai konsep produk, reward memperkuat keterlibatan — tetapi bukan alasan
/// utama bermain. Karena itu poin yang belum cukup tidak ditampilkan sebagai
/// kegagalan, melainkan sebagai jarak: "kurang 300 poin — temukan hero lagi".
class RewardStorePage extends StatelessWidget {
  const RewardStorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RewardStoreCubit>(
      create: (_) => RewardStoreCubit(sl<RewardRepository>())..load(),
      child: const _RewardStoreView(),
    );
  }
}

class _RewardStoreView extends StatelessWidget {
  const _RewardStoreView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: BlocBuilder<RewardStoreCubit, RewardStoreState>(
        builder: (context, state) {
          final cubit = context.read<RewardStoreCubit>();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: cubit.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _StoreHeader(balance: state.balance)),
                const SliverToBoxAdapter(child: _ChallengesBanner()),
                if (state.isLoading && state.rewards.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: LoadingView(message: 'Memuat Reward Store…'),
                  )
                else if (state.failure != null && state.rewards.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: FailureView(
                        failure: state.failure!, onRetry: cubit.load),
                  )
                else if (state.rewards.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      icon: Icons.redeem_rounded,
                      title: 'Hadiah segera hadir',
                      message:
                          'Reward Store sedang disiapkan. Sementara itu, kumpulkan NUSA POINTS '
                          'dengan menemukan hero dan menyelesaikan kuis.',
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: _CategoryChips(
                      categories: state.availableCategories,
                      selected: state.category,
                      onSelected: cubit.selectCategory,
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      HomeShell.reservedBottom(context) + 16,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 240,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.70,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final reward = state.visibleRewards[index];
                          return _RewardCard(
                            reward: reward,
                            balance: state.balance,
                            onTap: () => _openReward(context, reward),
                          );
                        },
                        childCount: state.visibleRewards.length,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openReward(BuildContext context, Reward reward) async {
    final cubit = context.read<RewardStoreCubit>();
    final redemption = await showModalBottomSheet<Redemption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _RewardDetailSheet(reward: reward),
      ),
    );
    if (redemption == null || !context.mounted) return;

    // Saldo di kartu profil ikut berubah.
    await context.read<AuthCubit>().refreshUser();
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RedeemSuccessSheet(redemption: redemption),
    );
  }
}

// ─────────────────────────── Header ────────────────────────────

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: AppColors.redWhite,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Reward Store',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Saldo NUSA POINTS',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.textOnDark.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const PointsCoin(size: 30),
                  const SizedBox(width: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: balance.toDouble(), end: balance.toDouble()),
                    duration: const Duration(milliseconds: 500),
                    builder: (context, value, _) => Text(
                      formatPoints(value.round()),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _HeaderButton(
                      icon: Icons.receipt_long_rounded,
                      label: 'Penukaranku',
                      onTap: () => context.push(AppRoutes.myRedemptions),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeaderButton(
                      icon: Icons.history_rounded,
                      label: 'Riwayat Poin',
                      onTap: () => context.push(AppRoutes.pointHistory),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.textOnDark),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textOnDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jalan pintas ke tantangan — cara tercepat menambah poin di luar menemukan hero.
class _ChallengesBanner extends StatelessWidget {
  const _ChallengesBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(AppRoutes.challenges),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    color: AppColors.gold, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tantangan Harian & Mingguan',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text(
                        'Selesaikan tantangan untuk poin tambahan hingga 500.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<RewardCategory> categories;
  final RewardCategory? selected;
  final ValueChanged<RewardCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.length < 2) return const SizedBox(height: 12);

    Widget chip(String label, RewardCategory? value) {
      final isOn = selected == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: isOn,
          onSelected: (_) => onSelected(value),
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: isOn ? AppColors.textOnDark : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
          showCheckmark: false,
        ),
      );
    }

    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        children: [
          chip('Semua', null),
          for (final category in categories) chip(category.label, category),
        ],
      ),
    );
  }
}

// ─────────────────────────── Kartu ─────────────────────────────

class _RewardCard extends StatelessWidget {
  const _RewardCard(
      {required this.reward, required this.balance, required this.onTap});

  final Reward reward;
  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortfall = reward.pointsCost - balance;
    final affordable = shortfall <= 0;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _RewardArt(reward: reward),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _Tag(
                      text: reward.category.label,
                      color: AppColors.primary,
                    ),
                  ),
                  if (reward.isOutOfStock)
                    const Positioned(
                      right: 10,
                      top: 10,
                      child: _Tag(text: 'Habis', color: AppColors.danger),
                    )
                  else if (reward.stock != null && reward.stock! <= 10)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: _Tag(
                          text: 'Sisa ${reward.stock}',
                          color: AppColors.accent),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const PointsCoin(size: 16),
                      const SizedBox(width: 5),
                      Text(
                        formatPoints(reward.pointsCost),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.goldDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (affordable)
                    Text(
                      reward.isAvailable ? 'Bisa ditukar' : 'Belum tersedia',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: reward.isAvailable
                            ? AppColors.success
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (balance / reward.pointsCost).clamp(0, 1),
                        minHeight: 5,
                        backgroundColor: AppColors.surfaceMuted,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.gold),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kurang ${formatPoints(shortfall)} poin',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardArt extends StatelessWidget {
  const _RewardArt({required this.reward});

  final Reward reward;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primaryDark],
        ),
      ),
      child: Center(
        child: Icon(reward.category.icon, size: 46, color: AppColors.gold),
      ),
    );

    final url = reward.imageUrl;
    if (url == null || url.isEmpty) return fallback;

    return Image.network(
      resolveBackendAssetUrl(url),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─────────────────────── Detail & penukaran ────────────────────

class _RewardDetailSheet extends StatelessWidget {
  const _RewardDetailSheet({required this.reward});

  final Reward reward;

  Future<void> _redeem(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tukar hadiah ini?'),
        content: Text(
          '${formatPoints(reward.pointsCost)} NUSA POINTS akan dipotong dari saldomu '
          'untuk "${reward.name}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tukar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final redemption = await context.read<RewardStoreCubit>().redeem(reward);
      if (context.mounted) Navigator.pop(context, redemption);
    } on Failure catch (failure) {
      if (!context.mounted) return;
      showFailureSnack(context, failure);
      // Stok habis / hadiah ditarik: tutup lembar ini, katalog sudah dimuat ulang.
      if (failure.code == ApiErrorCode.rewardOutOfStock ||
          failure.code == ApiErrorCode.rewardUnavailable) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<RewardStoreCubit, RewardStoreState>(
      builder: (context, state) {
        final isRedeeming = state.redeemingId == reward.id;
        final shortfall = reward.pointsCost - state.balance;
        final canRedeem = reward.isAvailable && shortfall <= 0 && !isRedeeming;

        final label = !reward.isAvailable
            ? (reward.isOutOfStock ? 'Stok habis' : 'Belum tersedia')
            : shortfall > 0
                ? 'Kurang ${formatPoints(shortfall)} poin'
                : isRedeeming
                    ? 'Menukar…'
                    : 'Tukar ${formatPoints(reward.pointsCost)} poin';

        return _SheetFrame(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(height: 170, child: _RewardArt(reward: reward)),
              ),
              const SizedBox(height: 16),
              Text(
                reward.category.label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                reward.name,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                reward.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const PointsCoin(size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${formatPoints(reward.pointsCost)} NUSA POINTS',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.goldDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  if (reward.stock != null)
                    Text(
                      reward.isOutOfStock
                          ? 'Stok habis'
                          : 'Sisa ${reward.stock}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                ],
              ),
              if (reward.howToClaim != null) ...[
                const SizedBox(height: 14),
                _InfoBox(
                  icon: Icons.info_outline_rounded,
                  text: reward.howToClaim!,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: canRedeem ? () => _redeem(context) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              if (shortfall > 0 && reward.isAvailable) ...[
                const SizedBox(height: 10),
                Text(
                  'Temukan hero, selesaikan kuis dan misi untuk menambah poinmu.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RedeemSuccessSheet extends StatelessWidget {
  const _RedeemSuccessSheet({required this.redemption});

  final Redemption redemption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.celebration_rounded,
                size: 34, color: AppColors.success),
          ),
          const SizedBox(height: 14),
          Text(
            'Berhasil ditukar!',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            redemption.rewardName,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          RedemptionCodeBox(code: redemption.code),
          if (redemption.howToClaim != null) ...[
            const SizedBox(height: 14),
            _InfoBox(
                icon: Icons.info_outline_rounded, text: redemption.howToClaim!),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.myRedemptions);
                  },
                  child: const Text('Penukaranku'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kode penukaran besar yang bisa disalin — inilah yang ditunjukkan ke petugas.
class RedemptionCodeBox extends StatelessWidget {
  const RedemptionCodeBox({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: code));
          if (context.mounted) showInfoSnack(context, 'Kode $code disalin.');
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold, width: 1.5),
          ),
          child: Column(
            children: [
              const Text(
                'KODE PENUKARAN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                code,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: AppColors.primary,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ketuk untuk menyalin · tunjukkan ke petugas',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
