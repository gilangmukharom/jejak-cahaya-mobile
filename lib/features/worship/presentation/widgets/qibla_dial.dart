import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Piringan kompas yang menunjukkan arah kiblat relatif terhadap arah hadap.
///
/// Yang berputar adalah piringannya, bukan penunjuknya. Penunjuk kiblat tetap
/// mengikuti sudutnya sendiri, tetapi mata pengguna selalu menemukan jawabannya
/// di tempat yang sama: **puncak lingkaran**. Ketika penanda emas sampai di
/// sana, perangkat sudah menghadap kiblat.
///
/// Itulah alasan tanda arah kiblat diberi bentuk yang berbeda dari jarum utara
/// alih-alih sekadar warna lain — pada layar di bawah matahari langsung, warna
/// adalah hal pertama yang hilang.
class QiblaDial extends StatelessWidget {
  const QiblaDial({
    required this.headingDeg,
    required this.qiblaBearingDeg,
    required this.isAligned,
    this.compact = false,
    super.key,
  });

  /// Arah hadap perangkat, 0° = utara.
  final double headingDeg;

  /// Sudut kiblat dari posisi pengguna, 0° = utara.
  final double qiblaBearingDeg;

  /// Apakah perangkat sudah lurus menghadap kiblat.
  final bool isAligned;

  /// Versi kecil untuk kartu ringkas: tanpa mata angin dan tanpa garis derajat.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Tanpa animasi dengan sengaja. Kehalusan putarannya sudah diurus penghalus
    // di `QiblaService`, yang meredam derau magnetometer pada selisih terpendek
    // — dan animasi tambahan di sini justru merusaknya: setiap kali jarum
    // melewati utara, nilainya melompat dari 359° ke 1°, dan animasi akan
    // memutar piringan hampir satu lingkaran penuh ke arah yang salah.
    return CustomPaint(
      painter: _QiblaDialPainter(
        headingDeg: headingDeg,
        qiblaBearingDeg: qiblaBearingDeg,
        isAligned: isAligned,
        compact: compact,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _QiblaDialPainter extends CustomPainter {
  const _QiblaDialPainter({
    required this.headingDeg,
    required this.qiblaBearingDeg,
    required this.isAligned,
    required this.compact,
  });

  final double headingDeg;
  final double qiblaBearingDeg;
  final bool isAligned;
  final bool compact;

  static const List<(String, double)> _cardinals = [
    ('U', 0),
    ('T', 90),
    ('S', 180),
    ('B', 270),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - (compact ? 2 : 18);
    if (radius <= 0) return;

    _paintFace(canvas, center, radius);

    // Sudut layar = sudut kompas − arah hadap. Nol berada di puncak lingkaran,
    // jadi seluruh sudut dikurangi 90° saat diubah ke koordinat kanvas.
    if (!compact) {
      _paintTicks(canvas, center, radius);
      _paintCardinals(canvas, center, radius);
    }

    _paintNorthNeedle(canvas, center, radius);
    _paintQiblaMarker(canvas, center, radius);

    canvas.drawCircle(
      center,
      compact ? 3 : 5,
      Paint()..color = AppColors.primary,
    );
  }

  void _paintFace(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AppColors.cream,
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 2 : 3
        ..color = isAligned ? AppColors.gold : AppColors.surfaceMuted,
    );
  }

  void _paintTicks(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.5)
      ..strokeCap = StrokeCap.round;

    for (var degrees = 0; degrees < 360; degrees += 15) {
      final isMajor = degrees % 45 == 0;
      final length = isMajor ? 10.0 : 5.0;
      paint.strokeWidth = isMajor ? 2 : 1;

      final angle = _radiansFor(degrees.toDouble());
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final inner =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - length);

      canvas.drawLine(inner, outer, paint);
    }
  }

  void _paintCardinals(Canvas canvas, Offset center, double radius) {
    for (final (label, degrees) in _cardinals) {
      final angle = _radiansFor(degrees);
      final position =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius + 12);

      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: degrees == 0 ? AppColors.danger : AppColors.textSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  /// Jarum utara — merah, tipis, dan sengaja tidak menonjol.
  void _paintNorthNeedle(Canvas canvas, Offset center, double radius) {
    final angle = _radiansFor(0);
    final tip =
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.8;

    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = AppColors.danger.withValues(alpha: 0.65)
        ..strokeWidth = compact ? 1.5 : 2
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Penanda kiblat: segitiga gemuk di tepi piringan, dengan garis ke pusat.
  void _paintQiblaMarker(Canvas canvas, Offset center, double radius) {
    final angle = _radiansFor(qiblaBearingDeg);
    final direction = Offset(math.cos(angle), math.sin(angle));
    final color = isAligned ? AppColors.gold : AppColors.primary;

    canvas.drawLine(
      center,
      center + direction * radius * 0.86,
      Paint()
        ..color = color.withValues(alpha: 0.75)
        ..strokeWidth = compact ? 2 : 3
        ..strokeCap = StrokeCap.round,
    );

    final tip = center + direction * radius * 0.98;
    final size = compact ? 6.0 : 11.0;

    // Segitiga dibangun dari arah tegak lurus penunjuknya, sehingga ia selalu
    // menghadap keluar berapa pun sudutnya.
    final perpendicular = Offset(-direction.dy, direction.dx);
    final base = center + direction * (radius * 0.98 - size * 1.4);

    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          (base + perpendicular * size * 0.62).dx,
          (base + perpendicular * size * 0.62).dy,
        )
        ..lineTo(
          (base - perpendicular * size * 0.62).dx,
          (base - perpendicular * size * 0.62).dy,
        )
        ..close(),
      Paint()..color = color,
    );
  }

  /// Dari sudut kompas ke sudut kanvas, sudah memperhitungkan arah hadap.
  double _radiansFor(double compassDegrees) =>
      (compassDegrees - headingDeg - 90) * math.pi / 180;

  @override
  bool shouldRepaint(covariant _QiblaDialPainter oldDelegate) =>
      oldDelegate.headingDeg != headingDeg ||
      oldDelegate.qiblaBearingDeg != qiblaBearingDeg ||
      oldDelegate.isAligned != isAligned ||
      oldDelegate.compact != compact;
}
