import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/achievement.dart';
import '../../../../core/models/scan_result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

/// Layar "Kamu Mendapatkan!" setelah scan berhasil.
///
/// Ini imbalan atas perjalanan fisik pemain, jadi sengaja dirayakan: kartu
/// tokoh, XP yang diperoleh, kenaikan level, dan pencapaian yang terbuka
/// ditampilkan sekaligus sebelum mengarahkan ke kisah dan quiz.
class DiscoveryResultPage extends StatefulWidget {
  const DiscoveryResultPage({required this.result, super.key});

  final ScanResult result;

  @override
  State<DiscoveryResultPage> createState() => _DiscoveryResultPageState();
}

class _DiscoveryResultPageState extends State<DiscoveryResultPage> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2))
      ..play();

    // XP bertambah setelah penemuan, jadi kartu profil perlu disegarkan.
    // Dilakukan di sini, bukan saat berpindah dari pemindai: emisi state dari
    // AuthCubit ikut menyegarkan router, dan bila itu terjadi tepat di tengah
    // navigasi, layar ini bisa tergantikan sebelum sempat dibaca pemain.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthCubit>().refreshUser();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final collectible = result.collectible;

    // Layar ini adalah imbalan atas perjalanan fisik pemain, dan memuat satu-
    // satunya tautan menuju quiz tokoh yang baru ditemukan. Karena itu ia hanya
    // boleh ditutup lewat tombol yang terlihat — bukan oleh gestur kembali atau
    // tombol back perangkat yang mudah tersenggol.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            DecoratedBox(
              decoration:
                  const BoxDecoration(gradient: AppColors.primaryGradient),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => context.go(AppRoutes.explore),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textOnDark,
                          ),
                          tooltip: 'Tutup',
                        ),
                      ),
                      Text(
                        'KAMU MENDAPATKAN',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.gold,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _CollectibleCard(result: result),
                      const SizedBox(height: 24),
                      _XpChip(xp: result.xpEarned),
                      if (result.levelUp != null) ...[
                        const SizedBox(height: 14),
                        _LevelUpBanner(levelUp: result.levelUp!),
                      ],
                      if (result.missionCompleted) ...[
                        const SizedBox(height: 14),
                        _MissionCompleteBanner(
                          title: result.missionProgress?.title ?? 'Misi',
                        ),
                      ],
                      if (result.unlockedAchievements.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _AchievementsUnlocked(
                          achievements: result.unlockedAchievements,
                        ),
                      ],
                      const SizedBox(height: 32),
                      if (result.hasQuiz && result.quizId != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.pushReplacement(
                              AppRoutes.quiz(result.quizId!),
                            ),
                            icon: const Icon(Icons.quiz_rounded, size: 20),
                            label: const Text('Jawab Quiz & Dapatkan XP'),
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
                          onPressed: () => context.pushReplacement(
                            AppRoutes.collectibleDetail(collectible.slug),
                          ),
                          icon: const Icon(Icons.menu_book_rounded, size: 20),
                          label: const Text('Baca Kisah Lengkap'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textOnDark,
                            side: BorderSide(
                              color:
                                  AppColors.textOnDark.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.explore),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              AppColors.textOnDark.withValues(alpha: 0.7),
                        ),
                        child: const Text('Lanjut Menjelajah'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirection: math.pi / 2,
                emissionFrequency: 0.05,
                numberOfParticles: 16,
                gravity: 0.25,
                shouldLoop: false,
                colors: const [
                  AppColors.gold,
                  AppColors.goldLight,
                  AppColors.primaryLight,
                  Colors.white,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu koleksi dengan bingkai berwarna sesuai kelangkaan.
class _CollectibleCard extends StatelessWidget {
  const _CollectibleCard({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collectible = result.collectible;
    final rarityValue = collectible.rarity.value;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: AppColors.rarityGradient(rarityValue),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.rarity(rarityValue).withValues(alpha: 0.5),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(23),
        ),
        child: Column(
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              // Gambar tokoh belum tersedia pada MVP; ikon dipakai sebagai
              // penanda agar tata letak kartu sudah final saat aset masuk.
              child: Icon(
                collectible.type.value == 'ARTIFACT'
                    ? Icons.museum_rounded
                    : Icons.person_rounded,
                size: 72,
                color: AppColors.rarity(rarityValue),
              ),
            ),
            const SizedBox(height: 18),
            RarityBadge(rarity: rarityValue),
            const SizedBox(height: 12),
            Text(
              collectible.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (collectible.title != null) ...[
              const SizedBox(height: 6),
              Text(
                collectible.title!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.gold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (collectible.era != null) ...[
              const SizedBox(height: 10),
              Text(
                '${collectible.era}${collectible.region != null ? ' · ${collectible.region}' : ''}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textOnDark.withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              collectible.summary,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textOnDark.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.place_rounded,
                    size: 14, color: AppColors.gold),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    result.checkpointName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textOnDark.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _XpChip extends StatelessWidget {
  const _XpChip({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '+$xp XP',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _LevelUpBanner extends StatelessWidget {
  const _LevelUpBanner({required this.levelUp});

  final LevelUp levelUp;

  @override
  Widget build(BuildContext context) {
    return _Banner(
      icon: Icons.trending_up_rounded,
      color: AppColors.success,
      title: 'Naik Level!',
      subtitle: 'Level ${levelUp.from} → ${levelUp.to}',
    );
  }
}

class _MissionCompleteBanner extends StatelessWidget {
  const _MissionCompleteBanner({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _Banner(
      icon: Icons.flag_circle_rounded,
      color: AppColors.gold,
      title: 'Misi Selesai!',
      subtitle: title,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.textOnDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.7),
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

class _AchievementsUnlocked extends StatelessWidget {
  const _AchievementsUnlocked({required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final achievement in achievements) ...[
          _Banner(
            icon: Icons.military_tech_rounded,
            color: AppColors.goldLight,
            title: 'Pencapaian Terbuka',
            subtitle: '${achievement.title} · +${achievement.xpReward} XP',
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
