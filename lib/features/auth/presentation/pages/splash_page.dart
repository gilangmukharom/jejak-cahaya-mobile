import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';

/// Ditampilkan selama sesi tersimpan diperiksa ke server.
///
/// Router menahan pengguna di sini sampai [AuthCubit] selesai memutuskan,
/// sehingga tidak ada kedipan layar masuk bagi pengguna yang masih login.
///
/// Animasinya dibangun dengan framework Flutter sendiri, bukan Lottie: tidak
/// ada berkas animasi yang dibundel, dan splash tidak boleh bergantung pada
/// aset yang harus dimuat lebih dulu.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  /// Animasi masuk: logo, cincin, lalu teks — dijalankan sekali.
  late final AnimationController _intro;

  /// Denyut cincin yang berulang selama menunggu, sekaligus menjadi penanda
  /// bahwa aplikasi sedang bekerja — menggantikan spinner biasa.
  late final AnimationController _pulse;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<double> _titleSlide;
  late final Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // elasticOut memberi sedikit pantulan pada logo — cukup untuk terasa hidup
    // tanpa menahan pengguna, karena pemeriksaan sesi berjalan bersamaan.
    _logoScale = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.55, curve: Curves.elasticOut),
    );
    _logoFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.3, curve: Curves.easeOut),
    );
    _titleFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
    );
    _titleSlide = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.35, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _taglineFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.6, 1, curve: Curves.easeOut),
    );

    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_intro, _pulse]),
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _RingPainter(
                          progress: _pulse.value,
                          opacity: _logoFade.value,
                        ),
                        child: Center(
                          child: Opacity(
                            opacity: _logoFade.value.clamp(0, 1),
                            child: Transform.scale(
                              scale: _logoScale.value.clamp(0, 1.4),
                              child: child,
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.22),
                        border: Border.all(color: AppColors.gold, width: 2),
                      ),
                      child: const Icon(
                        Icons.mosque_rounded,
                        size: 52,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedBuilder(
                  animation: _intro,
                  builder: (context, child) => Opacity(
                    opacity: _titleFade.value.clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(0, _titleSlide.value),
                      child: child,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        AppConfig.appName.toUpperCase(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ISLAMIC EXPLORER',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.textOnDark.withValues(alpha: 0.7),
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 44),
                FadeTransition(
                  opacity: _taglineFade,
                  child: Text(
                    AppConfig.appTagline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textOnDark.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dua cincin yang mengembang keluar dari logo lalu memudar.
///
/// Perannya sama dengan spinner — memberi tahu bahwa aplikasi sedang bekerja —
/// tetapi menyatu dengan identitas visual alih-alih menempel di atasnya.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.opacity});

  /// 0→1 berulang.
  final double progress;

  /// Meredam cincin selama logo belum sepenuhnya muncul.
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    const minRadius = 54.0;
    final maxRadius = size.width / 2;

    // Dua cincin berselang setengah siklus agar denyutnya terasa berkelanjutan.
    for (final offset in [0.0, 0.5]) {
      final t = (progress + offset) % 1.0;
      final radius = minRadius + (maxRadius - minRadius) * t;
      final fade = (1 - t) * opacity;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = AppColors.gold.withValues(alpha: (fade * 0.55).clamp(0, 1)),
      );
    }

    // Busur tipis yang berputar pelan — penanda bahwa proses masih berjalan.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: minRadius - 4),
      progress * 2 * math.pi,
      math.pi / 2.2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color =
            AppColors.gold.withValues(alpha: (0.85 * opacity).clamp(0, 1)),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.opacity != opacity;
}
