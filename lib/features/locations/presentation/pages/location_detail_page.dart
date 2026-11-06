import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/mission.dart';
import '../../../../core/models/mosque.dart';
import '../../../../core/services/scan_result_holder.dart';
import '../../../../core/utils/distance.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../game/data/game_repository.dart';
import '../../../game/presentation/cubit/geofence_cubit.dart';
import '../../../mission/presentation/cubit/mission_cubit.dart';
import '../widgets/progress_ring.dart';

/// Detail satu lokasi: kemajuan pemain di sana, dan misi apa yang menunggu.
///
/// Ini yang membuat lokasi menjadi sesuatu yang bisa dipilih, bukan hanya
/// didatangi. Misi ditampilkan dengan status lengkap — termasuk untuk lokasi
/// yang belum pernah dikunjungi — sehingga seseorang bisa memutuskan akan ke
/// mana berdasarkan isinya, bukan hanya jaraknya.
///
/// Daftar misinya memakai [MissionCubit] yang sama dengan tab Misi. Misi memang
/// selalu milik satu masjid; yang berubah hanyalah dari layar mana masjid itu
/// ditentukan.
class LocationDetailPage extends StatelessWidget {
  const LocationDetailPage({required this.mosqueId, super.key});

  final String mosqueId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<GeofenceCubit>.value(value: sl<GeofenceCubit>()),
        BlocProvider<MissionCubit>(
          create: (_) =>
              MissionCubit(sl<GameRepository>(), sl<ScanResultHolder>())
                ..loadMissions(mosqueId),
        ),
      ],
      child: _LocationDetailView(mosqueId: mosqueId),
    );
  }
}

class _LocationDetailView extends StatelessWidget {
  const _LocationDetailView({required this.mosqueId});

  final String mosqueId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GeofenceCubit, GeofenceState>(
      builder: (context, geofence) {
        final mosque = _find(geofence);

        if (mosque == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Lokasi')),
            body: const LoadingView(message: 'Memuat lokasi…'),
          );
        }

        final isCurrent = geofence.mosque?.id == mosque.id;

        return Scaffold(
          backgroundColor: AppColors.cream,
          body: CustomScrollView(
            slivers: [
              _Hero(mosque: mosque),
              SliverToBoxAdapter(child: _ProgressCard(mosque: mosque)),
              if (mosque.description != null &&
                  mosque.description!.trim().isNotEmpty)
                SliverToBoxAdapter(child: _About(text: mosque.description!)),
              const SliverToBoxAdapter(child: _SectionTitle('Misi di lokasi ini')),
              const _MissionSliver(),
              SliverToBoxAdapter(
                child: _PlayButton(mosque: mosque, isCurrent: isCurrent),
              ),
            ],
          ),
        );
      },
    );
  }

  Mosque? _find(GeofenceState state) {
    for (final mosque in state.mosques) {
      if (mosque.id == mosqueId) return mosque;
    }
    return null;
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.mosque});

  final Mosque mosque;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInside = mosque.isInside == true;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 190,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnDark,
      flexibleSpace: FlexibleSpaceBar(
        background: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mosque.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mosque.address ?? mosque.placeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textOnDark.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Status area dianimasikan karena ia benar-benar berubah
                  // sementara layar terbuka: pemain yang berjalan mendekat
                  // melihatnya berganti dari jarak menjadi "Anda di area ini".
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    child: Container(
                      key: ValueKey(isInside),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isInside
                            ? AppColors.success
                            : AppColors.textOnDark.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isInside
                                ? Icons.check_circle_rounded
                                : Icons.directions_walk_rounded,
                            size: 15,
                            color: AppColors.textOnDark,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isInside
                                ? 'Anda berada di area ini'
                                : mosque.distanceM == null
                                    ? 'Jarak belum diketahui'
                                    : '${formatDistance(mosque.distanceM!)} dari sini',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textOnDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.mosque});

  final Mosque mosque;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = mosque.progress;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      child: Row(
        children: [
          ProgressRing(
            value: progress?.fraction ?? 0,
            label: progress == null
                ? '0/${mosque.checkpointCount}'
                : '${progress.discoveredCheckpoints}/${progress.totalCheckpoints}',
            size: 72,
            isComplete: progress?.isCompleted ?? false,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress == null
                      ? 'Kemajuan di lokasi ini'
                      : progress.isCompleted
                          ? 'Lokasi ini sudah tuntas'
                          : progress.isUntouched
                              ? 'Belum ada yang ditemukan di sini'
                              : '${progress.remainingCheckpoints} tokoh lagi di sini',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  progress == null
                      ? '${mosque.checkpointCount} titik · ${mosque.missionCount} misi'
                      : '${progress.completedMissions}/${progress.totalMissions} misi selesai'
                          '${progress.xpEarned > 0 ? ' · ${progress.xpEarned} XP dari lokasi ini' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
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

class _About extends StatelessWidget {
  const _About({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MissionSliver extends StatelessWidget {
  const _MissionSliver();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MissionCubit, MissionState>(
      builder: (context, state) {
        if (state.isLoading && state.missions.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: LoadingView(message: 'Memuat misi…'),
            ),
          );
        }

        if (state.missions.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                'Pengurus belum menyiapkan misi di lokasi ini.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: state.missions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _MissionRow(
              mission: state.missions[index],
              index: index,
            ),
          ),
        );
      },
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.mission, required this.index});

  final Mission mission;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocked = mission.status.isLocked;
    final isCompleted = mission.status.isCompleted;

    final accent = isCompleted
        ? AppColors.success
        : isLocked
            ? AppColors.textMuted
            : AppColors.gold;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 70),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // Misi terkunci tidak dibuka: isinya membocorkan tokoh yang belum
          // semestinya diketahui pemain.
          onTap: isLocked
              ? null
              : () => context.push(AppRoutes.missionDetail(mission.id)),
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: isLocked ? 0.55 : 1,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceMuted),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : isLocked
                              ? Icons.lock_outline_rounded
                              : Icons.flag_rounded,
                      color: accent,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mission.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: TweenAnimationBuilder<double>(
                            tween:
                                Tween<double>(begin: 0, end: mission.progress),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) =>
                                LinearProgressIndicator(
                              value: value,
                              minHeight: 5,
                              backgroundColor: AppColors.surfaceMuted,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    mission.progressLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Membuka lokasi ini di peta.
///
/// Ditandai berbeda ketika pemain berada di luar areanya: tombolnya tetap
/// bekerja — peta menampilkan lokasi beserta sisa jaraknya — tetapi tidak
/// menjanjikan permainan yang terbuka, karena Layer 1 tetap berlaku.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.mosque, required this.isCurrent});

  final Mosque mosque;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final isInside = mosque.isInside == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 36),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () async {
            await context.read<GeofenceCubit>().selectMosque(mosque.id);
            if (!context.mounted) return;
            context.go(AppRoutes.explore);
          },
          style: FilledButton.styleFrom(
            backgroundColor: isInside ? AppColors.primary : AppColors.gold,
            foregroundColor:
                isInside ? AppColors.textOnDark : AppColors.primaryDark,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          icon: Icon(
            isInside ? Icons.explore_rounded : Icons.map_outlined,
            size: 19,
          ),
          label: Text(
            isInside
                ? 'Mulai menjelajah di sini'
                : isCurrent
                    ? 'Lihat di peta'
                    : 'Jadikan lokasi saya',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
