import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/user.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/supported_by_pik2.dart';
import '../../../game/presentation/pages/home_shell.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../game/data/game_repository.dart';
import '../cubit/profile_cubit.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>(
      create: (_) => ProfileCubit(
        authRepository: sl<AuthRepository>(),
        gameRepository: sl<GameRepository>(),
      )..load(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
          ),
        ],
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (state.isLoading && state.stats == null) {
            return const LoadingView();
          }

          final failure = state.failure;
          if (failure != null && state.stats == null) {
            return FailureView(
              failure: failure,
              onRetry: () => context.read<ProfileCubit>().load(),
            );
          }

          final stats = state.stats;

          return RefreshIndicator(
            onRefresh: () => context.read<ProfileCubit>().load(),
            child: ListView(
              // Cangkang memakai `extendBody: true`, jadi badan halaman
              // membentang di belakang bilah navigasi. Padding tetap 28 membuat
              // isi terakhir — di sini kredit sponsor — tertutup bilah itu.
              // `reservedBottom` menghitung tinggi bilah, marginnya, dan area
              // aman perangkat sekaligus.
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                HomeShell.reservedBottom(context) + 16,
              ),
              children: [
                if (user != null) _ProfileHeader(user: user, stats: stats),
                const SizedBox(height: 20),
                if (stats != null) _StatsGrid(stats: stats),
                const SizedBox(height: 20),

                // Misi tidak lagi punya tab sendiri sejak slotnya diberikan ke
                // Ibadah. Selain lewat bilah misi di atas peta, di sinilah ia
                // dijangkau — dan di sini ia tetap terbuka meski pemain sedang
                // jauh dari masjid mana pun.
                _MenuTile(
                  icon: Icons.flag_rounded,
                  title: 'Misi',
                  subtitle: 'Daftar tokoh yang bisa ditemukan',
                  onTap: () => context.push(AppRoutes.missions),
                ),
                const SizedBox(height: 10),

                // Ditempatkan tepat setelah Misi karena keduanya menjawab
                // pertanyaan yang bersambung: apa yang tersisa untuk saya
                // kerjakan, dan di mana saja saya bisa mengerjakannya.
                _MenuTile(
                  icon: Icons.travel_explore_rounded,
                  title: 'Lokasi Penjelajahan',
                  subtitle: 'Masjid yang bisa dimainkan & kemajuan di tiap lokasi',
                  onTap: () => context.push(AppRoutes.locations),
                ),
                const SizedBox(height: 10),
                _MenuTile(
                  icon: Icons.military_tech_rounded,
                  title: 'Pencapaian',
                  subtitle:
                      '${state.unlockedAchievements.length} dari ${state.achievements.length} terbuka',
                  onTap: () => context.push(AppRoutes.achievements),
                ),
                const SizedBox(height: 10),
                _MenuTile(
                  icon: Icons.leaderboard_rounded,
                  title: 'Papan Peringkat',
                  subtitle: stats?.rank != null
                      ? 'Peringkat Anda #${stats!.rank}'
                      : 'Lihat peringkat pemain lain',
                  onTap: () => context.push(AppRoutes.leaderboard),
                ),
                const SizedBox(height: 10),
                _MenuTile(
                  icon: Icons.collections_bookmark_rounded,
                  title: 'Koleksi Saya',
                  subtitle: stats != null
                      ? '${stats.discoveryCount} dari ${stats.totalCollectibles} tokoh & artefak'
                      : 'Lihat tokoh yang sudah ditemukan',
                  onTap: () => context.go(AppRoutes.collection),
                ),

                // Kredit sponsor. Splash hanya tampil sekejap saat sesi
                // diperiksa — sering kurang dari sedetik bagi pengguna yang
                // sudah login — jadi kreditnya juga ditaruh di sini, di tempat
                // yang bisa dibuka kapan saja.
                const SizedBox(height: 34),
                const Center(child: SupportedByPik2(logoWidth: 104)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final authCubit = context.read<AuthCubit>();

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Progres Anda tersimpan di server dan akan kembali saat masuk lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) await authCubit.logout();
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, this.stats});

  final User user;
  final PlayerStats? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = stats?.levelProgress;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            // Lencana level lebih pendek daripada blok nama dua baris; tanpa
            // ini keduanya diregangkan sama tinggi dan angkanya melayang.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  user.initials,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textOnDark,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textOnDark.withValues(alpha: 0.6),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LEVEL',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.gold,
                        letterSpacing: 1,
                        fontSize: 9,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${level?.level ?? user.level}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          XpProgressBar(
            progress: level?.progress ?? 0,
            label: level == null
                ? '${user.totalXp} XP'
                : level.isMaxLevel
                    ? '${level.totalXp} XP · Level maksimum'
                    // Dipersingkat dari "XP lagi menuju level N": kalimat panjang
                    // terpotong pada ponsel sempit, sementara angkanya yang penting.
                    : '${level.totalXp} XP · ${level.xpToNextLevel} XP lagi ke Lv ${level.level + 1}',
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      // 1.7 memberi tinggi sekitar 105 dp, sementara isi kartu (ikon, angka,
      // label, dan padding) butuh sekitar 118 dp — selisihnya muncul sebagai
      // garis overflow di layar. 1.45 menyisakan ruang yang cukup.
      childAspectRatio: 1.45,
      children: [
        _StatTile(
          icon: Icons.auto_stories_rounded,
          value: '${stats.discoveryCount}/${stats.totalCollectibles}',
          label: 'Tokoh ditemukan',
          color: AppColors.primary,
        ),
        _StatTile(
          icon: Icons.flag_rounded,
          value: '${stats.missionsCompleted}/${stats.missionsTotal}',
          label: 'Misi selesai',
          color: AppColors.gold,
        ),
        _StatTile(
          icon: Icons.quiz_rounded,
          value: '${stats.quizzesPassed}',
          label: 'Quiz lulus',
          color: AppColors.success,
        ),
        _StatTile(
          icon: Icons.stars_rounded,
          value: '${stats.perfectQuizzes}',
          label: 'Nilai sempurna',
          color: AppColors.info,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 8),
          // Nilai seperti "14/14" atau "100" berbeda lebarnya; FittedBox
          // mengecilkannya bila perlu alih-alih memotong angka.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceMuted),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
