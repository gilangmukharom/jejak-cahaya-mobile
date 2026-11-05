import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';

final NumberFormat _points = NumberFormat.decimalPattern('id');

/// `12500` → `12.500`.
String formatPoints(int value) => _points.format(value);

/// Koin NUSA POINTS: lingkaran Victory Gold dengan bintang — selaras dengan
/// "bintang emas" pada konsep logo NUSAVERSE.
class PointsCoin extends StatelessWidget {
  const PointsCoin({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
        ),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.6), width: size * 0.06),
      ),
      child: Icon(Icons.star_rounded, size: size * 0.66, color: Colors.white),
    );
  }
}

/// Pil "+120 NUSA POINTS" untuk layar hasil scan dan kuis.
class PointsEarnedChip extends StatelessWidget {
  const PointsEarnedChip({required this.points, this.onDark = true, super.key});

  final int points;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.10)
            : AppColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PointsCoin(size: 22),
          const SizedBox(width: 8),
          Text(
            '+${formatPoints(points)} NUSA POINTS',
            style: TextStyle(
              color: onDark ? AppColors.gold : AppColors.goldDark,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
