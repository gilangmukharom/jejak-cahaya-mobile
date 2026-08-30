import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../models/scan_result.dart';

/// Menampilkan rantai kemajuan: langkah yang barusan terbuka, lalu langkah
/// berikutnya yang masih digembok.
///
/// Gemboknya benar-benar dianimasikan terbuka — hasapnya terangkat dan berputar,
/// badannya berdenyut, lalu berganti menjadi centang. Setelah itu kartu langkah
/// berikutnya masuk dari bawah dengan gembok tertutup, sehingga pemain langsung
/// mengerti bahwa perjalanannya belum selesai dan ke mana harus melangkah.
class UnlockProgress extends StatefulWidget {
  const UnlockProgress({
    required this.unlockedLabel,
    required this.progress,
    this.nextCheckpoint,
    super.key,
  });

  /// Nama titik yang barusan dibuka.
  final String unlockedLabel;

  /// Berapa titik sudah ditemukan dari total keseluruhan.
  final ({int discovered, int total}) progress;

  /// Titik berikutnya. Null berarti seluruh checkpoint sudah ditemukan.
  final NextCheckpoint? nextCheckpoint;

  @override
  State<UnlockProgress> createState() => _UnlockProgressState();
}

class _UnlockProgressState extends State<UnlockProgress>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _shackleLift;
  late final Animation<double> _lockScale;
  late final Animation<double> _checkFade;
  late final Animation<double> _barFill;
  late final Animation<double> _nextFade;
  late final Animation<double> _nextSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Urutannya disengaja: gembok terbuka dulu, bilah kemajuan menyusul, baru
    // langkah berikutnya muncul. Menampilkan semuanya sekaligus membuat momen
    // "terbuka"-nya hilang.
    _shackleLift = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.35, curve: Curves.easeOutBack),
    );
    _lockScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.18), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.5, curve: Curves.easeOut),
      ),
    );
    _checkFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.6, curve: Curves.easeOut),
    );
    _barFill = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.8, curve: Curves.easeOutCubic),
    );
    _nextFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 1, curve: Curves.easeOut),
    );
    _nextSlide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.72, 1, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.progress.total;
    final discovered = widget.progress.discovered;
    final ratio = total > 0 ? discovered / total : 0.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Transform.scale(
                      scale: _lockScale.value,
                      child: CustomPaint(
                        painter: _OpenLockPainter(
                          lift: _shackleLift.value,
                          checkOpacity: _checkFade.value,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TERBUKA',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.unlockedLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.textOnDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Bilah kemajuan yang terisi setelah gemboknya terbuka.
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio * _barFill.value,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '$discovered dari $total titik ditemukan',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textOnDark.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 14),

            Opacity(
              opacity: _nextFade.value.clamp(0, 1),
              child: Transform.translate(
                offset: Offset(0, _nextSlide.value),
                child: widget.nextCheckpoint == null
                    ? const _AllCompleteCard()
                    : _NextLockedCard(next: widget.nextCheckpoint!),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Kartu langkah berikutnya — sengaja tetap tampil tergembok.
class _NextLockedCard extends StatelessWidget {
  const _NextLockedCard({required this.next});

  final NextCheckpoint next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.lock_rounded,
              size: 24,
              color: AppColors.textOnDark.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BERIKUTNYA · TITIK ${next.playOrder}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  next.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (next.hint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    next.hint!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textOnDark.withValues(alpha: 0.55),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllCompleteCard extends StatelessWidget {
  const _AllCompleteCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded,
              size: 30, color: AppColors.gold),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Seluruh titik telah kamu temukan. Barakallahu fiik!',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gembok yang membuka: hasapnya terangkat dan miring, lalu badannya diisi
/// centang.
class _OpenLockPainter extends CustomPainter {
  const _OpenLockPainter({required this.lift, required this.checkOpacity});

  /// 0 = tertutup, 1 = terbuka penuh.
  final double lift;
  final double checkOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.16, size.height * 0.44, size.width * 0.68,
          size.height * 0.46),
      const Radius.circular(6),
    );

    // Hasap digambar lebih dulu agar tertutup badan gemboknya.
    canvas.save();
    final pivot = Offset(size.width * 0.7, size.height * 0.46);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(lift * 0.5);
    canvas.translate(-pivot.dx, -pivot.dy - lift * size.height * 0.12);

    canvas.drawArc(
      Rect.fromLTWH(size.width * 0.29, size.height * 0.14, size.width * 0.42,
          size.height * 0.44),
      3.14159,
      3.14159,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.gold,
    );
    canvas.restore();

    canvas.drawRRect(bodyRect, Paint()..color = AppColors.gold);

    if (checkOpacity > 0) {
      final center = bodyRect.center;
      final path = Path()
        ..moveTo(center.dx - size.width * 0.14, center.dy)
        ..lineTo(center.dx - size.width * 0.04, center.dy + size.height * 0.09)
        ..lineTo(center.dx + size.width * 0.15, center.dy - size.height * 0.10);

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color =
              AppColors.primaryDark.withValues(alpha: checkOpacity.clamp(0, 1)),
      );
    }
  }

  @override
  bool shouldRepaint(_OpenLockPainter oldDelegate) =>
      oldDelegate.lift != lift || oldDelegate.checkOpacity != checkOpacity;
}
