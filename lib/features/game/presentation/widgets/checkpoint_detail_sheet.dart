import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/checkpoint.dart';
import '../../../../core/widgets/app_widgets.dart';

/// Rincian satu checkpoint.
///
/// Pada daftar, petunjuk lokasi dipangkas satu baris supaya barisnya rapat —
/// padahal justru kalimat itulah yang dibutuhkan pemain untuk menemukan QR.
/// Lembar ini menampilkannya utuh, beserta jarak, status, dan aksi lanjutannya.
class CheckpointDetailSheet extends StatelessWidget {
  const CheckpointDetailSheet({required this.checkpoint, super.key});

  final Checkpoint checkpoint;

  static Future<void> show(BuildContext context, Checkpoint checkpoint) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CheckpointDetailSheet(checkpoint: checkpoint),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discovered = checkpoint.isDiscovered;
    final inRange = checkpoint.isInRange ?? false;

    final accent = discovered
        ? AppColors.success
        : inRange
            ? AppColors.gold
            : AppColors.textMuted;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      discovered
                          ? Icons.verified_rounded
                          : Icons.location_on_outlined,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          checkpoint.name,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          checkpoint.code,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Petunjuk lokasi ditampilkan utuh — ini alasan utama lembar ini ada.
              if (checkpoint.hint != null && checkpoint.hint!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded,
                              size: 16, color: AppColors.goldDark),
                          const SizedBox(width: 6),
                          Text(
                            'PETUNJUK LOKASI QR',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.goldDark,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        checkpoint.hint!,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      icon: Icons.straighten_rounded,
                      label: 'Jarak',
                      value: checkpoint.distanceLabel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      icon: Icons.adjust_rounded,
                      label: 'Radius',
                      value: '${checkpoint.radiusMeters} m',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      icon: discovered
                          ? Icons.check_circle_outline_rounded
                          : Icons.pending_outlined,
                      label: 'Status',
                      value: discovered ? 'Ditemukan' : 'Belum',
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (discovered) ...[
                Row(
                  children: [
                    RarityBadge(
                        rarity: checkpoint.collectiblePreview.rarity.value),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        checkpoint.collectiblePreview.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(
                        AppRoutes.collectibleDetail(
                          checkpoint.collectiblePreview.id,
                        ),
                      );
                    },
                    icon: const Icon(Icons.menu_book_rounded, size: 20),
                    label: const Text('Baca Kisah & Quiz'),
                  ),
                ),
              ] else ...[
                Text(
                  inRange
                      ? 'Anda sudah cukup dekat. Cari QR-nya lalu pindai.'
                      : 'Berjalanlah mendekat sampai jaraknya di bawah '
                          '${checkpoint.radiusMeters} m, lalu pindai QR di lokasi.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary, height: 1.55),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(AppRoutes.scanner);
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: const Text('Pindai QR'),
                    style: inRange
                        ? ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.primaryDark,
                          )
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color ?? AppColors.textSecondary),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: AppColors.textMuted, height: 1.2),
          ),
        ],
      ),
    );
  }
}
