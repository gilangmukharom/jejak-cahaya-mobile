import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Cincin progres yang mengisi dirinya sendiri saat pertama muncul.
///
/// Dipakai pada kartu lokasi. Bentuk cincin dipilih alih-alih bilah karena
/// kartu lokasi memuat empat angka sekaligus — titik, misi, XP, jarak — dan
/// bilah horizontal ketiga hanya akan menambah satu garis lagi ke tumpukan
/// yang sudah padat. Cincin menempati sudut yang memang kosong dan terbaca
/// sekali lihat: seberapa penuh, bukan berapa persisnya.
///
/// Animasinya bukan hiasan: kartu-kartu ini berubah nilainya setelah pemain
/// memindai sesuatu, dan cincin yang bergerak dari nilai lama ke nilai baru
/// memberi tahu bahwa penemuan barusan memang tercatat di lokasi ini.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.value,
    required this.label,
    this.size = 54,
    this.color = AppColors.primary,
    this.isComplete = false,
    super.key,
  });

  /// 0–1.
  final double value;

  /// Teks di tengah cincin, mis. "3/6".
  final String label;

  final double size;
  final Color color;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, animated, child) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            value: animated,
            color: isComplete ? AppColors.success : color,
          ),
          child: Center(child: child),
        ),
      ),
      child: isComplete
          ? const Icon(Icons.check_rounded,
              size: 22, color: AppColors.success)
          : Text(
              label,
              style: TextStyle(
                fontSize: size * 0.24,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.11;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.surfaceMuted;

    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      // Dimulai dari puncak, bukan dari sisi kanan seperti bawaan Canvas —
      // arah yang sama dengan jam, dan satu-satunya yang terbaca sebagai
      // "mengisi" alih-alih "berputar".
      -math.pi / 2,
      2 * math.pi * value,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}
