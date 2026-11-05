import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/collectible.dart';
import '../../../../core/services/app_settings.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/narration_button.dart';
import '../../data/ar_capability.dart';
import '../../data/model_cache.dart';
import 'model_3d_view.dart';
import 'native_ar_view.dart';

/// Tokoh hadir di sekitar pemain, beserta penjelasannya.
///
/// Urutannya: model diunduh (penjelasan sudah bisa dibaca selama menunggu) →
/// kamera AR menyala dan tokoh otomatis berdiri di lantai pertama yang
/// terlihat. Bila AR tidak tersedia — perangkat tanpa ARCore, iOS, sesi gagal —
/// tokohnya tetap tampil sebagai model 3D yang bisa diputar, jadi tidak ada
/// pemain yang pulang tanpa melihat tokohnya.
///
/// Dipakai dua layar: langsung setelah scan QR (dengan [primaryAction] menuju
/// hadiah XP & quiz), dan dari halaman koleksi untuk melihatnya lagi.
class ArExperience extends StatefulWidget {
  const ArExperience({
    required this.collectible,
    required this.onBack,
    this.checkpointName,
    this.primaryAction,
    super.key,
  });

  /// Harus sudah ditemukan dan punya `modelUrl`.
  final Collectible collectible;
  final VoidCallback onBack;
  final String? checkpointName;

  /// Tombol yang selalu terlihat di dasar layar, di bawah lembar penjelasan.
  final Widget? primaryAction;

  @override
  State<ArExperience> createState() => _ArExperienceState();
}

enum _Stage { preparing, ar, model3d, failed }

class _ArExperienceState extends State<ArExperience> {
  /// Tinggi lembar penjelasan saat tertutup, tanpa tombol aksi.
  static const double _sheetPeek = 176;
  static const double _actionBarHeight = 76;

  /// Batas menunggu jawaban ARCore. Pada perangkat normal jawabannya datang
  /// dalam ratusan milidetik.
  static const Duration _arCheckTimeout = Duration(seconds: 6);

  /// Batas menunggu gambar pertama dari kamera AR. Lewat dari ini tanpa
  /// satu bingkai pun, tokohnya ditampilkan dalam 3D — pemain tidak boleh
  /// ditinggal menatap layar kosong.
  static const Duration _cameraWatchdog = Duration(seconds: 12);

  _Stage _stage = _Stage.preparing;
  bool _arSupported = false;
  bool _placed = false;
  double? _progress;
  ModelSource? _source;

  /// Tahap AR terakhir dari SceneView (nama `PlacementPhase`).
  String? _arPhase;
  bool _hasCameraFrame = false;
  Timer? _watchdog;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    setState(() {
      _stage = _Stage.preparing;
      _progress = null;
      _source = null;
      _placed = false;
    });

    try {
      // Keduanya berjalan bersamaan: pemeriksaan ARCore biasanya selesai jauh
      // sebelum unduhan, jadi tidak ada waktu yang terbuang menunggunya.
      //
      // Batas waktunya wajib. ARCore bisa lama sekali — atau tidak pernah —
      // menjawab, mis. saat Google Play Services for AR belum terpasang dan ia
      // masih bertanya ke Play Store. Lewat batas, tokohnya ditampilkan dalam
      // 3D: pemain tetap melihatnya, dan sakelar di atas masih bisa mencoba AR.
      // Opsi tanpa AR (Pengaturan): langsung 3D, kamera tidak dinyalakan.
      final supported = sl<AppSettings>().arEnabled
          ? sl<ArCapability>()
              .isSupported()
              .timeout(_arCheckTimeout, onTimeout: () => false)
          : Future<bool>.value(false);

      // Model bawaan dibaca langsung dari APK (seketika); selain itu diunduh.
      final source = await sl<ModelCache>().resolve(
        widget.collectible.modelUrl!,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (!mounted) return;
      // Model siap; yang tersisa hanya jawaban ARCore. Ditandai supaya layar
      // tidak lagi menampilkan "100%" yang terlihat seperti macet.
      setState(() => _source = source);

      final arSupported = await supported;
      if (!mounted) return;

      setState(() => _arSupported = arSupported);
      if (arSupported) {
        _enterAr();
      } else {
        setState(() => _stage = _Stage.model3d);
      }
    } on Object catch (error) {
      debugPrint('AR: model tidak bisa disiapkan — $error');
      if (mounted) setState(() => _stage = _Stage.failed);
    }
  }

  /// Masuk ke kamera AR, dengan pengaman: bila kamera tidak pernah memberi
  /// gambar, beralih ke 3D alih-alih menampilkan layar kosong selamanya.
  void _enterAr() {
    _watchdog?.cancel();
    setState(() {
      _stage = _Stage.ar;
      _placed = false;
      _arPhase = null;
      _hasCameraFrame = false;
    });
    _watchdog = Timer(_cameraWatchdog, () {
      if (!_hasCameraFrame) {
        _fallBackTo3d(
          'Kamera AR tidak menampilkan gambar — tokoh ditampilkan dalam 3D.',
        );
      }
    });
  }

  void _onArPhase(String phase, bool hasCameraFrame) {
    if (!mounted) return;
    setState(() {
      _arPhase = phase;
      _hasCameraFrame = hasCameraFrame;
    });
    if (hasCameraFrame) _watchdog?.cancel();
    if (phase == 'CAMERA_ERROR') {
      _fallBackTo3d(
          'Kamera AR tidak bisa dimulai — tokoh ditampilkan dalam 3D.');
    }
  }

  Future<void> _retryAfterBrokenFile() async {
    final source = _source;
    if (source == null || !source.isBundled) {
      await sl<ModelCache>().evict(widget.collectible.modelUrl!);
    }
    await _prepare();
  }

  void _fallBackTo3d(String message) {
    if (!mounted || _stage != _Stage.ar) return;
    _watchdog?.cancel();
    setState(() => _stage = _Stage.model3d);
    showInfoSnack(context, message);
  }

  void _toggleMode() {
    if (_stage == _Stage.ar) {
      _watchdog?.cancel();
      setState(() {
        _placed = false;
        _stage = _Stage.model3d;
      });
    } else {
      _enterAr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final hasAction = widget.primaryAction != null;
    final bottomChrome =
        _sheetPeek + (hasAction ? _actionBarHeight : 0) + media.padding.bottom;
    final minSheet = (bottomChrome / media.size.height).clamp(0.15, 0.5);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: AppColors.primaryDark,
          child: _buildStage(bottomChrome),
        ),
        _TopBar(
          title: widget.collectible.name,
          onBack: widget.onBack,
          stage: _stage,
          canToggle:
              _arSupported && (_stage == _Stage.ar || _stage == _Stage.model3d),
          onToggle: _toggleMode,
        ),
        if (_stage == _Stage.ar)
          _placed ? const _PlacedChip() : _ArStatusChip(phase: _arPhase),
        if (_stage == _Stage.ar && sl<AppSettings>().familyMode)
          const _FamilySafetyChip(),
        DraggableScrollableSheet(
          initialChildSize: minSheet,
          minChildSize: minSheet,
          maxChildSize: 0.88,
          snap: true,
          builder: (context, controller) => _StorySheet(
            collectible: widget.collectible,
            checkpointName: widget.checkpointName,
            controller: controller,
            bottomPadding:
                (hasAction ? _actionBarHeight : 0) + media.padding.bottom + 24,
          ),
        ),
        if (hasAction)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                10 + media.padding.bottom,
              ),
              child: widget.primaryAction,
            ),
          ),
      ],
    );
  }

  Widget _buildStage(double bottomChrome) {
    final source = _source;
    switch (_stage) {
      case _Stage.preparing:
        return _PreparingView(
          progress: _progress,
          downloaded: source != null,
          bottomInset: bottomChrome,
        );
      case _Stage.failed:
        return _FailedView(
          bottomInset: bottomChrome,
          onRetry: _retryAfterBrokenFile,
        );
      case _Stage.ar:
        return NativeArView(
          key: ValueKey('ar-${source!.id}'),
          source: source,
          animation: widget.collectible.modelAnimation,
          bottomInset: bottomChrome,
          onPhase: _onArPhase,
          onPlaced: () {
            unawaited(HapticFeedback.mediumImpact());
            setState(() => _placed = true);
          },
          onUnsupported: () {
            sl<ArCapability>().markUnsupported();
            setState(() => _arSupported = false);
            _fallBackTo3d(
              'Perangkat ini belum mendukung AR — tokoh ditampilkan dalam 3D.',
            );
          },
          onSessionFailed: (_) => _fallBackTo3d(
            'Kamera AR tidak bisa dimulai — tokoh ditampilkan dalam 3D.',
          ),
          onModelFailed: () => setState(() => _stage = _Stage.failed),
        );
      case _Stage.model3d:
        return Padding(
          padding: EdgeInsets.only(bottom: bottomChrome - 24),
          child: Model3dView(
            key: ValueKey('3d-${source!.id}'),
            source: source,
            alt: 'Model 3D ${widget.collectible.name}',
            animation: widget.collectible.modelAnimation,
            onFailed: () => setState(() => _stage = _Stage.failed),
          ),
        );
    }
  }
}

/// Pengingat keselamatan Mode Keluarga — konsep produk: perlindungan anak dan
/// tidak mendorong pemain memasuki area berbahaya atau terlarang.
class _FamilySafetyChip extends StatelessWidget {
  const _FamilySafetyChip();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 104, 24, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.family_restroom_rounded,
                    size: 16, color: Colors.white),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Perhatikan sekitarmu & tetap bersama pendamping',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
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

/// Keterangan singkat tahap AR sebelum tokoh berdiri di lantai.
///
/// Selain menuntun pemain, ini juga jalan cepat mendiagnosis di lapangan:
/// bila tulisannya berganti ("Arahkan kamera ke lantai…") tetapi gambar
/// kameranya tidak terlihat, mesin AR-nya berjalan dan yang bermasalah adalah
/// penampilannya — bukan model atau ARCore.
class _ArStatusChip extends StatelessWidget {
  const _ArStatusChip({required this.phase});

  final String? phase;

  @override
  Widget build(BuildContext context) {
    final text = switch (phase) {
      'SCANNING' => 'Arahkan kamera ke lantai, gerakkan perlahan',
      'NO_SURFACE' => 'Lantai belum terlihat — cari tempat terang & bertekstur',
      'TRACKING_LOST' ||
      'RECOVERING' =>
        'Arahkan kembali ke tempat tokoh berdiri',
      'RECOVERY_FAILED' =>
        'Tokoh hilang dari pandangan — gerakkan ponsel perlahan',
      _ => 'Menyalakan kamera AR…',
    };

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.stage,
    required this.canToggle,
    required this.onToggle,
  });

  final String title;
  final VoidCallback onBack;
  final _Stage stage;
  final bool canToggle;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              _GlassButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Kembali',
                onPressed: onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 8),
                    ],
                  ),
                ),
              ),
              if (canToggle)
                _GlassButton(
                  icon: stage == _Stage.ar
                      ? Icons.threed_rotation_rounded
                      : Icons.view_in_ar_rounded,
                  tooltip: stage == _Stage.ar
                      ? 'Tampilkan sebagai model 3D'
                      : 'Tampilkan dalam AR',
                  onPressed: onToggle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: Colors.white,
        tooltip: tooltip,
      ),
    );
  }
}

/// Konfirmasi singkat begitu tokoh berdiri di lantai.
class _PlacedChip extends StatelessWidget {
  const _PlacedChip();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 350),
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * -8),
                child: child,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Cubit untuk mengubah ukuran · putar dua jari untuk memutar',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreparingView extends StatelessWidget {
  const _PreparingView({
    required this.progress,
    required this.downloaded,
    required this.bottomInset,
  });

  final double? progress;

  /// Model sudah tersimpan di ponsel; tinggal menyiapkan kamera AR.
  final bool downloaded;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Setelah unduhan selesai bilahnya tidak lagi menunjukkan persen — "100%"
    // yang diam terbaca sebagai macet — melainkan bergerak tak tentu selama
    // kamera AR disiapkan.
    final value = downloaded ? null : progress;
    final percent = value == null ? null : (value * 100).round();
    final title = downloaded
        ? 'Menyiapkan kamera AR…'
        : percent == null
            ? 'Memanggil tokoh…'
            : 'Memanggil tokoh… $percent%';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.view_in_ar_rounded,
                size: 52,
                color: AppColors.gold,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: AppColors.textOnDark),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: AppColors.textOnDark.withValues(alpha: 0.12),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                downloaded
                    ? 'Sebentar lagi tokohnya hadir di sekitarmu.'
                    : 'Hanya sekali di awal — setelah ini tokohnya tersimpan di ponselmu. '
                        'Sambil menunggu, baca kisahnya di bawah.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textOnDark.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.bottomInset, required this.onRetry});

  final double bottomInset;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: AppColors.textOnDark.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 18),
              Text(
                'Tokoh belum bisa dihadirkan',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textOnDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Model 3D gagal diunduh. Periksa koneksi internet, lalu coba lagi.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textOnDark.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lembar penjelasan tokoh: ringkas saat tertutup, kisah lengkap saat ditarik.
class _StorySheet extends StatelessWidget {
  const _StorySheet({
    required this.collectible,
    required this.controller,
    required this.bottomPadding,
    this.checkpointName,
  });

  final Collectible collectible;
  final ScrollController controller;
  final double bottomPadding;
  final String? checkpointName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final story = collectible.story;
    final paragraphs = story == null
        ? const <String>[]
        : story
            .split(RegExp(r'\n\s*\n'))
            .map((paragraph) => paragraph.trim())
            .where((paragraph) => paragraph.isNotEmpty)
            .toList();
    final meta =
        [collectible.era, collectible.region].whereType<String>().join(' · ');

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 18)],
      ),
      child: ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(24, 10, 24, bottomPadding),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              RarityBadge(rarity: collectible.rarity.value, compact: true),
              if (checkpointName != null) ...[
                const SizedBox(width: 10),
                const Icon(
                  Icons.place_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    checkpointName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            collectible.name,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (collectible.title != null) ...[
            const SizedBox(height: 2),
            Text(
              collectible.title!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.goldDark,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            collectible.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (story != null && story.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: NarrationButton(
                id: collectible.slug,
                text: '${collectible.name}. ${collectible.title ?? ''}. $story',
              ),
            ),
          ],
          if (paragraphs.isNotEmpty) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                Text(
                  'Kisahnya',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            for (final paragraph in paragraphs) ...[
              Text(
                paragraph,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 14),
            ],
          ],
        ],
      ),
    );
  }
}
