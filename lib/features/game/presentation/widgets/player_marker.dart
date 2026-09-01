import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Denyut dan kerucut arah di bawah avatar pemain.
///
/// Digambar sebagai penanda tersendiri dari [PlayerAvatar] karena keduanya
/// berperilaku berbeda saat peta diputar: kerucut arah harus ikut berputar
/// bersama peta agar tetap menunjuk ke arah yang benar di dunia nyata,
/// sementara avatarnya harus tetap tegak menghadap pemain. Satu penanda tidak
/// bisa melakukan keduanya sekaligus, jadi keduanya dipisah dan ditumpuk pada
/// koordinat yang sama.
///
/// Pasang dengan `Marker(rotate: false)` — nilai bawaan flutter_map, yang
/// berarti penanda ikut berputar bersama peta.
class PlayerAura extends StatefulWidget {
  const PlayerAura({
    required this.diameter,
    this.headingDeg,
    this.isMoving = false,
    super.key,
  });

  /// Sisi kotak penanda, dalam piksel logis.
  final double diameter;

  /// Arah gerak pemain dalam derajat kompas, atau null bila belum diketahui.
  final double? headingDeg;

  /// Saat pemain diam, denyutnya melambat. Perangkat yang tetap "bernapas"
  /// pelan memberi tahu bahwa GPS masih hidup tanpa menarik perhatian.
  final bool isMoving;

  @override
  State<PlayerAura> createState() => _PlayerAuraState();
}

class _PlayerAuraState extends State<PlayerAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: _pulseDuration())
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant PlayerAura oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _pulseDuration();
    if (_pulse.duration != next) {
      // Mengganti durasi menghentikan pengulangan, jadi harus dinyalakan lagi.
      _pulse
        ..duration = next
        ..repeat();
    }
  }

  Duration _pulseDuration() => widget.isMoving
      ? const Duration(milliseconds: 1500)
      : const Duration(milliseconds: 2600);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.diameter),
          painter: _PlayerAuraPainter(
            progress: _pulse.value,
            headingDeg: widget.headingDeg,
          ),
        ),
      ),
    );
  }
}

class _PlayerAuraPainter extends CustomPainter {
  const _PlayerAuraPainter({required this.progress, this.headingDeg});

  final double progress;
  final double? headingDeg;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // ── Kerucut arah ────────────────────────────────────────────
    // Digambar lebih dulu agar denyutnya menyapu di atasnya.
    final heading = headingDeg;
    if (heading != null) {
      const double sweep = math.pi / 3;
      // Kanvas mengukur sudut dari sumbu x positif (arah timur), sedangkan
      // derajat kompas diukur dari utara — karena itu digeser seperempat putaran.
      final start = (heading * math.pi / 180) - (math.pi / 2) - (sweep / 2);

      final cone = Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.info.withValues(alpha: 0.42),
            AppColors.info.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..arcTo(
            Rect.fromCircle(center: center, radius: maxRadius),
            start,
            sweep,
            false,
          )
          ..close(),
        cone,
      );
    }

    // ── Denyut ──────────────────────────────────────────────────
    // Dua gelombang berselang setengah putaran, sehingga selalu ada satu
    // lingkaran yang terlihat dan iramanya tidak pernah terputus.
    for (final phase in const [0.0, 0.5]) {
      final t = (progress + phase) % 1.0;
      final radius = maxRadius * (0.28 + 0.72 * t);
      final fade = (1 - t) * 0.55;

      canvas
        ..drawCircle(
          center,
          radius,
          Paint()..color = AppColors.info.withValues(alpha: fade * 0.22),
        )
        ..drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.info.withValues(alpha: fade),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _PlayerAuraPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.headingDeg != headingDeg;
}

/// Avatar pemain: titik terang yang selalu berada di tengah layar.
///
/// Pasang dengan `Marker(rotate: true)` agar tetap tegak ketika peta berputar.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryLight, AppColors.primaryDark],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // Ikonnya sengaja tidak berbentuk panah. Avatar ini tetap tegak ketika
        // peta berputar, jadi bentuk yang menyiratkan arah justru akan menunjuk
        // ke arah yang salah setiap kali peta tidak sedang mengikuti pemain.
        // Arah hadap disampaikan oleh kerucut pada [PlayerAura], yang memang
        // ikut berputar bersama peta.
        child: const Icon(
          Icons.person_rounded,
          size: 18,
          color: AppColors.gold,
        ),
      ),
    );
  }
}
