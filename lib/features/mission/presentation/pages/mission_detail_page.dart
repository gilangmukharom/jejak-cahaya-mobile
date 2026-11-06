import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/mission.dart';
import '../../../../core/services/scan_result_holder.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../game/data/game_repository.dart';
import '../cubit/mission_cubit.dart';

/// Rincian misi: daftar checkpoint terurut beserta status penemuannya.
class MissionDetailPage extends StatelessWidget {
  const MissionDetailPage({required this.missionId, super.key});

  final String missionId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MissionCubit>(
      create: (_) => MissionCubit(sl<GameRepository>(), sl<ScanResultHolder>())
        ..loadDetail(missionId),
      child: _MissionDetailView(missionId: missionId),
    );
  }
}

class _MissionDetailView extends StatelessWidget {
  const _MissionDetailView({required this.missionId});

  final String missionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Detail Misi'),
      ),
      body: BlocBuilder<MissionCubit, MissionState>(
        builder: (context, state) {
          if (state.isLoading && state.detail == null) {
            return const LoadingView();
          }

          final failure = state.failure;
          if (failure != null && state.detail == null) {
            return FailureView(
              failure: failure,
              onRetry: () => context.read<MissionCubit>().loadDetail(missionId),
            );
          }

          final detail = state.detail;
          if (detail == null) {
            return const EmptyView(
              icon: Icons.flag_outlined,
              title: 'Misi tidak ditemukan',
              message: 'Misi ini mungkin sudah dinonaktifkan pengurus masjid.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              _MissionSummary(mission: detail.mission),
              const SizedBox(height: 28),
              Text(
                'Checkpoint',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                detail.mission.type.value == 'SEQUENTIAL'
                    ? 'Selesaikan secara berurutan dari atas ke bawah.'
                    : 'Boleh dikunjungi dalam urutan bebas.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < detail.checkpoints.length; index++)
                _CheckpointStep(
                  checkpoint: detail.checkpoints[index],
                  stepNumber: index + 1,
                  isLast: index == detail.checkpoints.length - 1,
                  isNext:
                      detail.nextCheckpoint?.id == detail.checkpoints[index].id,
                ),
              const SizedBox(height: 24),
              if (detail.nextCheckpoint != null)
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.scanner),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: const Text('Pindai Checkpoint'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MissionSummary extends StatelessWidget {
  const _MissionSummary({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mission.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            mission.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textOnDark.withValues(alpha: 0.78),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          XpProgressBar(
            progress: mission.progress,
            label:
                '${mission.progressLabel} checkpoint · hadiah +${mission.xpReward} XP',
          ),
        ],
      ),
    );
  }
}

/// Satu langkah pada garis waktu misi.
class _CheckpointStep extends StatelessWidget {
  const _CheckpointStep({
    required this.checkpoint,
    required this.stepNumber,
    required this.isLast,
    required this.isNext,
  });

  final MissionCheckpoint checkpoint;
  final int stepNumber;
  final bool isLast;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discovered = checkpoint.isDiscovered;

    final accent = discovered
        ? AppColors.success
        : isNext
            ? AppColors.gold
            : AppColors.textMuted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kolom penanda + garis penghubung membentuk garis waktu vertikal.
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: discovered ? accent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2),
                ),
                child: discovered
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : Text(
                        '$stepNumber',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: discovered
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.surfaceMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isNext ? AppColors.gold : AppColors.surfaceMuted,
                    width: isNext ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      checkpoint.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // Tokoh pada checkpoint yang belum ditemukan sengaja tidak
                      // diungkap — penemuannya adalah inti permainan ini.
                      discovered
                          ? checkpoint.collectiblePreview?.name ?? 'Ditemukan'
                          : checkpoint.hint ?? 'Datangi lokasi lalu pindai QR',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    if (isNext) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tujuan berikutnya',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.goldDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
