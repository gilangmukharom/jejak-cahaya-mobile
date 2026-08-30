import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Satu langkah penuntun: menyorot sebuah widget lalu menjelaskannya.
class CoachStep {
  const CoachStep({
    required this.key,
    required this.title,
    required this.description,
    this.shape = BoxShape.rectangle,
  });

  /// Kunci yang dipasang pada widget yang ingin disorot. Langkah dilewati bila
  /// widget-nya sedang tidak terpasang — mis. radar yang hilang setelah seluruh
  /// checkpoint ditemukan.
  final GlobalKey key;

  final String title;
  final String description;
  final BoxShape shape;
}

/// Penuntun sekali-jalan yang menggelapkan layar, menyorot satu tombol, dan
/// menjelaskan fungsinya.
///
/// Dibuat sendiri, tanpa paket tambahan: kebutuhannya hanya sebuah lubang di
/// atas kain gelap dan sebuah kartu penjelasan. Lubangnya digambar memakai
/// [BlendMode.dstOut], sehingga tetap tajam pada kerapatan piksel berapa pun.
///
/// Pemanggilnya bertanggung jawab memastikan penuntun hanya tampil sekali —
/// lihat `AppPreferences.hasSeenOnboarding`.
class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({
    required this.steps,
    required this.onFinish,
    super.key,
  });

  final List<CoachStep> steps;
  final VoidCallback onFinish;

  /// Menampilkan penuntun di atas seluruh layar.
  ///
  /// Ditunda satu frame supaya widget yang disorot sudah selesai di-layout —
  /// tanpa itu, posisinya belum bisa dibaca dan sorotannya meleset.
  static void show(
    BuildContext context, {
    required List<CoachStep> steps,
    required VoidCallback onFinish,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => CoachMarkOverlay(
        steps: steps,
        onFinish: () {
          entry.remove();
          onFinish();
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => overlay.insert(entry));
  }

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Persegi yang ditempati widget target, dalam koordinat layar.
  Rect? _targetRect(CoachStep step) {
    final context = step.key.currentContext;
    if (context == null) return null;

    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;

    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _next() {
    if (_index >= widget.steps.length - 1) {
      widget.onFinish();
      return;
    }
    setState(() => _index += 1);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    // Langkah yang targetnya tidak terpasang dilewati diam-diam; menampilkan
    // sorotan pada posisi asal-asalan lebih membingungkan daripada tidak ada.
    var index = _index;
    Rect? rect;
    while (index < widget.steps.length) {
      rect = _targetRect(widget.steps[index]);
      if (rect != null) break;
      index += 1;
    }

    if (rect == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFinish());
      return const SizedBox.shrink();
    }

    if (index != _index) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => setState(() => _index = index));
    }

    final step = widget.steps[index];
    final spotlight = rect.inflate(10);
    final isLast = index >= widget.steps.length - 1;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Mengetuk di mana pun melanjutkan ke langkah berikutnya — pengguna
          // tidak perlu mencari tombol kecil untuk keluar dari penuntun.
          Positioned.fill(
            child: GestureDetector(
              onTap: _next,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  painter: _SpotlightPainter(
                    spotlight: spotlight,
                    shape: step.shape,
                    glow: _pulse.value,
                  ),
                ),
              ),
            ),
          ),
          _StepCard(
            step: step,
            spotlight: spotlight,
            screen: media.size,
            safeBottom: media.padding.bottom,
            stepNumber: index + 1,
            totalSteps: widget.steps.length,
            isLast: isLast,
            onNext: _next,
            onSkip: widget.onFinish,
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.spotlight,
    required this.screen,
    required this.safeBottom,
    required this.stepNumber,
    required this.totalSteps,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  final CoachStep step;
  final Rect spotlight;
  final Size screen;
  final double safeBottom;
  final int stepNumber;
  final int totalSteps;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Kartu diletakkan di sisi yang lebih lapang: bila sorotan berada di paruh
    // bawah layar, kartunya naik ke atas — dan sebaliknya.
    final showAbove = spotlight.center.dy > screen.height / 2;

    return Positioned(
      left: 20,
      right: 20,
      top: showAbove ? null : spotlight.bottom + 20,
      bottom: showAbove ? screen.height - spotlight.top + 20 : null,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(stepNumber),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * (showAbove ? -14 : 14)),
            child: child,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LANGKAH $stepNumber DARI $totalSteps',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.goldDark,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                step.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                step.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (!isLast)
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                      ),
                      child: const Text('Lewati'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(120, 44),
                    ),
                    child: Text(isLast ? 'Mulai Menjelajah' : 'Lanjut'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kain gelap dengan lubang di posisi target, ditambah cincin berdenyut.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.spotlight,
    required this.shape,
    required this.glow,
  });

  final Rect spotlight;
  final BoxShape shape;

  /// 0→1→0, dipakai untuk denyut cincin penanda.
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    // saveLayer diperlukan agar dstOut hanya berlaku pada kain ini, bukan pada
    // seluruh isi layar di bawahnya.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );

    final cut = Paint()..blendMode = BlendMode.dstOut;
    if (shape == BoxShape.circle) {
      canvas.drawCircle(spotlight.center, spotlight.longestSide / 2, cut);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(spotlight, const Radius.circular(16)),
        cut,
      );
    }
    canvas.restore();

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = AppColors.gold.withValues(alpha: 0.4 + glow * 0.6);

    if (shape == BoxShape.circle) {
      canvas.drawCircle(
        spotlight.center,
        spotlight.longestSide / 2 + glow * 6,
        ring,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          spotlight.inflate(glow * 6),
          const Radius.circular(16),
        ),
        ring,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.spotlight != spotlight ||
      oldDelegate.glow != glow ||
      oldDelegate.shape != shape;
}
