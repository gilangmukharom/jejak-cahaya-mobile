import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/checkpoint.dart';

/// Radar yang menunjukkan arah dan jarak ke checkpoint terdekat.
///
/// Peta saja tidak cukup di area masjid: jaraknya pendek (puluhan meter) dan
/// bangunannya rapat, sehingga pemain lebih terbantu oleh panah arah dan angka
/// jarak yang besar daripada titik di atas peta.
///
/// Denyut radarnya mengencang seiring pemain mendekat, jadi perangkatnya sendiri
/// terasa memberi umpan balik — bukan sekadar angka yang berubah.
class CheckpointRadar extends StatefulWidget {
  const CheckpointRadar({required this.checkpoint, this.onTap, super.key});

  final Checkpoint checkpoint;
  final VoidCallback? onTap;

  @override
  State<CheckpointRadar> createState() => _CheckpointRadarState();
}

class _CheckpointRadarState extends State<CheckpointRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(vsync: this, duration: _sweepDuration())
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant CheckpointRadar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final next = _sweepDuration();
    if (_sweep.duration != next) {
      // Mengganti durasi menghentikan pengulangan, jadi harus dinyalakan lagi.
      _sweep
        ..duration = next
        ..repeat();
    }
  }

  /// Semakin dekat, semakin cepat denyutnya: 2,4 detik saat jauh menjadi
  /// 0,7 detik saat sudah di dalam radius.
  Duration _sweepDuration() {
    final distance = widget.checkpoint.distanceM;
    if (distance == null) return const Duration(milliseconds: 2400);

    final radius = widget.checkpoint.radiusMeters.toDouble();
    final ratio = (distance / (radius * 6)).clamp(0.0, 1.0);
    return Duration(milliseconds: (700 + ratio * 1700).round());
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkpoint = widget.checkpoint;
    final inRange = checkpoint.isInRange ?? false;
    final accent = inRange ? AppColors.gold : AppColors.goldLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
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
            boxShadow: inRange
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.28),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _sweep,
                builder: (context, _) => SizedBox(
                  width: 82,
                  height: 82,
                  child: CustomPaint(
                    painter: _RadarPainter(
                      sweep: _sweep.value,
                      accent: accent,
                      inRange: inRange,
                    ),
                    child: Center(
                      child: inRange
                          ? Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 34,
                              // Berdenyut lembut saat sudah bisa dipindai.
                              color: Color.lerp(
                                AppColors.gold,
                                Colors.white,
                                (math.sin(_sweep.value * 2 * math.pi) + 1) / 2,
                              ),
                            )
                          : _DirectionArrow(bearingDeg: checkpoint.bearingDeg),
                    ),
                  ),
                ),
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
                        Expanded(
                          child: inRange
                              ? Text(
                                  'Pindai QR di lokasi',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : _AnimatedDistance(
                                  distanceM: checkpoint.distanceM,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w800,
                                  ),
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

/// Panah arah yang berputar mulus saat bearing berubah.
///
/// Tanpa transisi, pembaruan GPS membuat panah melompat-lompat dan justru
/// terasa rusak; interpolasi memilih arah putaran terpendek agar tidak
/// berputar hampir satu lingkaran penuh saat melewati 0°.
class _DirectionArrow extends StatefulWidget {
  const _DirectionArrow({required this.bearingDeg});

  final double? bearingDeg;

  @override
  State<_DirectionArrow> createState() => _DirectionArrowState();
}

class _DirectionArrowState extends State<_DirectionArrow> {
  /// Putaran kumulatif, sengaja tidak dibatasi ke rentang 0–1.
  ///
  /// Menyimpan sudut mentah membuat perpindahan 350° → 10° dianimasikan mundur
  /// hampir satu lingkaran penuh. Dengan menumpuk selisih terpendek, panahnya
  /// selalu berputar lewat jalur terdekat — dan boleh melewati batas 0 berkali-
  /// kali tanpa masalah.
  double _turns = 0;

  @override
  void initState() {
    super.initState();
    _turns = (widget.bearingDeg ?? 0) / 360;
  }

  @override
  void didUpdateWidget(covariant _DirectionArrow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bearingDeg == oldWidget.bearingDeg) return;

    final target = (widget.bearingDeg ?? 0) / 360;
    final current = _turns - _turns.floorToDouble();

    var delta = target - current;
    if (delta > 0.5) delta -= 1;
    if (delta < -0.5) delta += 1;

    setState(() => _turns += delta);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: _turns,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      child: const Icon(
        Icons.navigation_rounded,
        size: 38,
        color: AppColors.gold,
      ),
    );
  }
}

/// Angka jarak yang berjalan naik-turun alih-alih melompat.
class _AnimatedDistance extends StatelessWidget {
  const _AnimatedDistance({required this.distanceM, this.style});

  final double? distanceM;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final target = distanceM;
    if (target == null) {
      return Text('Menghitung jarak…', style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: target, end: target),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, _) => Text(
        value < 1000
            ? '${value.round()} m'
            : '${(value / 1000).toStringAsFixed(1).replaceAll('.', ',')} km',
        style: style,
      ),
    );
  }
}

/// Piringan radar: cincin statis, gelombang yang mengembang, dan sapuan berputar.
class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.sweep,
    required this.accent,
    required this.inRange,
  });

  final double sweep;
  final Color accent;
  final bool inRange;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius - 1,
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );

    // Cincin acuan, seperti skala pada layar radar.
    for (final factor in [0.45, 0.72, 1.0]) {
      canvas.drawCircle(
        center,
        (radius - 1) * factor,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = accent.withValues(alpha: 0.18),
      );
    }

    // Gelombang yang mengembang keluar — inti kesan "mendeteksi".
    for (final offset in [0.0, 0.5]) {
      final t = (sweep + offset) % 1.0;
      canvas.drawCircle(
        center,
        (radius - 1) * t,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = accent.withValues(alpha: ((1 - t) * 0.6).clamp(0, 1)),
      );
    }

    // Sapuan berputar hanya saat masih berjalan menuju titik; setelah sampai,
    // pencarian sudah selesai dan sapuannya justru mengganggu.
    if (!inRange) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 6),
        sweep * 2 * math.pi,
        math.pi / 3,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: sweep * 2 * math.pi,
            endAngle: sweep * 2 * math.pi + math.pi / 3,
            colors: [accent.withValues(alpha: 0), accent],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = inRange ? 2 : 1.2
        ..color = accent.withValues(alpha: inRange ? 0.9 : 0.4),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.sweep != sweep ||
      oldDelegate.accent != accent ||
      oldDelegate.inRange != inRange;
}
