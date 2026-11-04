import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/collectible.dart';

/// Tokoh sebagai model 3D yang bisa diputar — cadangan bila AR tidak tersedia.
///
/// Dipakai di perangkat tanpa ARCore, di iOS, dan bila sesi AR gagal dimulai.
/// Pemain tetap melihat tokohnya bergerak dan bisa memutarnya; yang hilang
/// hanya kamera di belakangnya. `ar` sengaja mati: tombol AR bawaan
/// `<model-viewer>` melempar pemain ke aplikasi Google, keluar dari permainan.
class Model3dView extends StatefulWidget {
  const Model3dView({
    required this.modelPath,
    required this.alt,
    this.animation,
    this.onFailed,
    super.key,
  });

  /// Jalur berkas GLB di perangkat.
  final String modelPath;
  final String alt;

  /// `Collectible.modelAnimation`: null = animasi pertama, `@none` = diam.
  final String? animation;
  final VoidCallback? onFailed;

  @override
  State<Model3dView> createState() => _Model3dViewState();
}

class _Model3dViewState extends State<Model3dView> {
  static const String _channelName = 'JejakModel';

  bool _loaded = false;

  void _onBridgeMessage(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic> || !mounted) return;

    switch (decoded['type']) {
      case 'load':
        setState(() => _loaded = true);
      case 'error':
        if (kDebugMode) debugPrint('3D: gagal memuat — ${decoded['detail']}');
        widget.onFailed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ModelViewer(
          id: 'tokoh',
          src: Uri.file(widget.modelPath).toString(),
          alt: widget.alt,
          backgroundColor: AppColors.primaryDark,
          loading: Loading.eager,
          cameraControls: true,
          disablePan: true,
          // Tanpa nama, <model-viewer> memutar animasi pertama di berkas.
          autoPlay: widget.animation != Collectible.animationNone,
          animationName: widget.animation == null ||
                  widget.animation == Collectible.animationNone
              ? null
              : widget.animation,
          shadowIntensity: 1,
          ar: false,
          debugLogging: kDebugMode,
          // Bilah progres bawaan dikosongkan; berkasnya sudah di perangkat dan
          // yang tersisa hanya penguraian, jadi cukup pemintal di bawah.
          innerModelViewerHtml: '<div slot="progress-bar"></div>',
          relatedJs: _bridgeJs,
          javascriptChannels: {
            JavascriptChannel(
              _channelName,
              onMessageReceived: (message) => _onBridgeMessage(message.message),
            ),
          },
        ),
        if (!_loaded)
          const IgnorePointer(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
            ),
          ),
      ],
    );
  }

  /// Meneruskan event `<model-viewer>` ke Flutter. Disisipkan setelah elemen
  /// `<model-viewer>`, jadi elemennya sudah ada saat skrip berjalan.
  static const String _bridgeJs = '''
(function () {
  var mv = document.getElementById('tokoh');
  function send(payload) {
    if (window.$_channelName) window.$_channelName.postMessage(JSON.stringify(payload));
  }
  mv.addEventListener('load', function () { send({ type: 'load' }); });
  mv.addEventListener('error', function (e) {
    send({ type: 'error', detail: String(e.detail && e.detail.type) });
  });
})();
''';
}
