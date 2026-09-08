import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/mission.dart';
import '../../../../core/services/scan_result_holder.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../game/data/game_repository.dart';
import '../../../game/presentation/cubit/geofence_cubit.dart';
import '../cubit/mission_cubit.dart';

/// Misi pada lokasi yang sedang dibuka.
///
/// Misi selalu milik satu masjid, jadi layar ini selalu bicara tentang satu
/// lokasi — dan sejak permainan berjalan di banyak masjid, lokasi itu harus
/// disebut namanya. Sebelumnya halaman ini membaca masjid terakhir dari
/// preferensi perangkat, yang bisa tertinggal beberapa lokasi di belakang
/// masjid yang sedang benar-benar dibuka di peta.
class MissionsPage extends StatelessWidget {
  const MissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final geofence = sl<GeofenceCubit>();

    // Preferensi dipakai hanya sebagai cadangan, ketika halaman dibuka sebelum
    // pemeriksaan geofence pertama sempat menghasilkan jawaban.
    final mosque = geofence.state.mosque;
    final mosqueId = mosque?.id ?? sl<AppPreferences>().lastMosqueId;

    return BlocProvider<MissionCubit>(
      create: (_) {
        final cubit =
            MissionCubit(sl<GameRepository>(), sl<ScanResultHolder>());
        if (mosqueId != null) cubit.loadMissions(mosqueId);
        return cubit;
      },
      child: _MissionsView(mosqueId: mosqueId, mosqueName: mosque?.name),
    );
  }
}

class _MissionsView extends StatelessWidget {
  const _MissionsView({this.mosqueId, this.mosqueName});

  final String? mosqueId;
  final String? mosqueName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Misi Eksplorasi'),
        actions: [
          IconButton(
            tooltip: 'Lokasi lain',
            onPressed: () => context.push(AppRoutes.locations),
            icon: const Icon(Icons.travel_explore_rounded),
          ),
        ],
        bottom: mosqueName == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(30),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.mosque_rounded,
                          size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          mosqueName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: mosqueId == null
          ? EmptyView(
              icon: Icons.mosque_outlined,
              title: 'Lokasi belum dipilih',
              message:
                  'Pilih lokasi penjelajahan lebih dulu untuk melihat misinya.',
              action: FilledButton.icon(
                onPressed: () => context.push(AppRoutes.locations),
                icon: const Icon(Icons.travel_explore_rounded, size: 18),
                label: const Text('Lihat daftar lokasi'),
              ),
            )
          : BlocBuilder<MissionCubit, MissionState>(
              builder: (context, state) {
                if (state.isLoading && state.missions.isEmpty) {
                  return const LoadingView(message: 'Memuat misi…');
                }

                final failure = state.failure;
                if (failure != null && state.missions.isEmpty) {
                  return FailureView(
                    failure: failure,
                    onRetry: () =>
                        context.read<MissionCubit>().loadMissions(mosqueId!),
                  );
                }

                if (state.missions.isEmpty) {
                  return const EmptyView(
                    icon: Icons.flag_outlined,
                    title: 'Belum ada misi',
                    message:
                        'Pengurus masjid belum menyiapkan misi eksplorasi.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      context.read<MissionCubit>().loadMissions(mosqueId!),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    itemCount: state.missions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _MissionCard(mission: state.missions[index]),
                  ),
                );
              },
            ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission});

  final Mission mission;

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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Misi terkunci tidak bisa dibuka: isinya akan membocorkan tokoh yang
        // belum semestinya diketahui pemain.
        onTap: isLocked
            ? null
            : () => context.push(AppRoutes.missionDetail(mission.id)),
        borderRadius: BorderRadius.circular(20),
        child: Opacity(
          opacity: isLocked ? 0.55 : 1,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCompleted
                    ? AppColors.success.withValues(alpha: 0.4)
                    : AppColors.surfaceMuted,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check_circle_rounded
                            : isLocked
                                ? Icons.lock_outline_rounded
                                : Icons.flag_rounded,
                        color: accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mission.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${mission.status.label} · ${mission.type == MissionType.sequential ? 'Berurutan' : 'Bebas'}',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+${mission.xpReward} XP',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.goldDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  mission.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: mission.progress,
                          minHeight: 7,
                          backgroundColor: AppColors.surfaceMuted,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
