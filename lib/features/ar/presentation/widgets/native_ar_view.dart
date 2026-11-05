import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../data/model_cache.dart';

/// Kamera AR native (ARCore + SceneView) dengan satu tokoh di lantai.
///
/// Sisi native-nya ada di `android/app/src/main/kotlin/.../ArPlatformView.kt`.
///
/// Memakai Hybrid Composition (`initExpensiveAndroidView`), bukan mode tekstur
/// bawaan: SceneView menggambar ke SurfaceView, dan SurfaceView tidak bisa
/// dipindahkan ke tekstur Flutter — di mode tekstur layarnya hitam.
class NativeArView extends StatefulWidget {
  const NativeArView({
    required this.source,
    this.animation,
    this.bottomInset = 0,
    this.onPlaced,
    this.onUnsupported,
    this.onSessionFailed,
    this.onModelFailed,
    this.onModelLoaded,
    this.onPhase,
    super.key,
  });

  static const String viewType = 'id.nusaverse/ar_view';

  /// Model yang ditampilkan: aset di APK atau berkas unduhan.
  final ModelSource source;

  /// Pilihan animasi dari panel admin (`Collectible.modelAnimation`); sisi
  /// native yang menerjemahkannya, termasuk jatuh ke animasi pertama bila
  /// namanya tidak ada di berkas.
  final String? animation;

  /// Ruang di bawah yang tertutup UI Flutter, dalam logical pixel. Panduan
  /// "gerakkan ponsel" milik SceneView digeser ke atasnya.
  final double bottomInset;

  final VoidCallback? onPlaced;
  final VoidCallback? onUnsupported;
  final ValueChanged<String>? onSessionFailed;
  final VoidCallback? onModelFailed;
  final VoidCallback? onModelLoaded;

  /// Tahap AR dari SceneView: nama `PlacementPhase` (mis. `SCANNING`,
  /// `PLACED`, `CAMERA_ERROR`) dan apakah gambar kamera sudah tiba.
  final void Function(String phase, bool hasCameraFrame)? onPhase;

  @override
  State<NativeArView> createState() => _NativeArViewState();
}

class _NativeArViewState extends State<NativeArView> {
  MethodChannel? _events;

  void _attach(int id) {
    _events = MethodChannel('${NativeArView.viewType}/$id')
      ..setMethodCallHandler((call) async {
        if (!mounted) return;
        switch (call.method) {
          case 'placed':
            widget.onPlaced?.call();
          case 'unsupported':
            widget.onUnsupported?.call();
          case 'sessionFailed':
            final args = call.arguments;
            widget.onSessionFailed
                ?.call(args is Map ? '${args['message']}' : 'unknown');
          case 'modelFailed':
            widget.onModelFailed?.call();
          case 'modelLoaded':
            widget.onModelLoaded?.call();
          case 'phase':
            final args = call.arguments;
            if (args is Map) {
              widget.onPhase?.call('${args['phase']}', args['camera'] == true);
            }
        }
      });
  }

  @override
  void dispose() {
    _events?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: NativeArView.viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        // Seluruh sentuhan di area kamera milik AR: cubit untuk mengubah
        // ukuran tokoh, putar dua jari untuk memutarnya. Widget Flutter yang
        // menumpuk di atasnya (lembar penjelasan, tombol) tetap menang karena
        // diuji lebih dulu.
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
        },
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: NativeArView.viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: <String, Object?>{
            if (widget.source.isBundled)
              'assetKey': widget.source.assetKey
            else
              'modelLocation': Uri.file(widget.source.filePath!).toString(),
            'bottomInsetDp': widget.bottomInset,
            'animation': widget.animation,
          },
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..addOnPlatformViewCreatedListener(_attach);
        controller.create();
        return controller;
      },
    );
  }
}
