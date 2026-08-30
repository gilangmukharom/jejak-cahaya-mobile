import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/checkpoint.dart';

/// Radar yang menunjukkan arah dan jarak ke checkpoint terdekat.
///
/// Peta saja tidak cukup di area masjid: jaraknya pendek (puluhan meter) dan
/// bangunannya rapat, sehingga pemain lebih terbantu oleh panah arah dan angka
/// jarak yang besar daripada oleh titik di atas peta.
class CheckpointRadar extends StatelessWidget {
  const CheckpointRadar({
    required this.checkpoint,
    this.onTap,
    super.key,
  });

  final Checkpoint checkpoint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = checkpoint.distanceM;
    final inRange = checkpoint.isInRange ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: inRange
                  ? AppColors.gold
                  : Colors.white.withValues(alpha: 0.12),
              width: inRange ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              _RadarDial(
                bearingDeg: checkpoint.bearingDeg,
                inRange: inRange,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      inRange ? 'Kamu sudah sampai!' : 'Jejak terdeteksi',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: inRange
                            ? AppColors.gold
                            : AppColors.textOnDark.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      checkpoint.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textOnDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (checkpoint.hint != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        checkpoint.hint!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textOnDark.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          inRange
                              ? Icons.qr_code_scanner_rounded
                              : Icons.directions_walk_rounded,
                          size: 18,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          inRange
                              ? 'Pindai QR di lokasi'
                              : distance == null
                                  ? 'Menghitung jarak…'
                                  : checkpoint.distanceLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Piringan radar dengan panah yang menunjuk ke arah checkpoint.
class _RadarDial extends StatelessWidget {
  const _RadarDial({required this.bearingDeg, required this.inRange});

  final double? bearingDeg;
  final bool inRange;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.25),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: inRange
          ? const Icon(Icons.check_circle_rounded,
              size: 38, color: AppColors.gold)
          : Transform.rotate(
              // Bearing dilaporkan dalam derajat kompas; Transform.rotate
              // memakai radian, dan 0 rad-nya menunjuk ke kanan — sementara
              // ikon panah ini menunjuk ke atas, yang sudah cocok dengan 0°.
              angle: (bearingDeg ?? 0) * math.pi / 180,
              child: const Icon(
                Icons.navigation_rounded,
                size: 38,
                color: AppColors.gold,
              ),
            ),
    );
  }
}
