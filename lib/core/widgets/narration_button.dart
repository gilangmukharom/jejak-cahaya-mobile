import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../di/injection.dart';
import '../services/narration_service.dart';
import 'app_widgets.dart';

/// Tombol "Dengarkan kisah" — membacakan [text] dengan suara bahasa Indonesia.
///
/// Narasinya berhenti sendiri bila tombol ini keluar dari layar (pemain
/// menutup halamannya), supaya suara tidak terus berjalan di layar lain.
class NarrationButton extends StatefulWidget {
  const NarrationButton({
    required this.id,
    required this.text,
    this.onDark = false,
    super.key,
  });

  /// Pengenal narasi, mis. slug pahlawan.
  final String id;
  final String text;
  final bool onDark;

  @override
  State<NarrationButton> createState() => _NarrationButtonState();
}

class _NarrationButtonState extends State<NarrationButton> {
  final NarrationService _narration = sl<NarrationService>();

  @override
  void dispose() {
    if (_narration.isSpeaking(widget.id)) _narration.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    final ok = await _narration.toggle(widget.id, widget.text);
    if (!ok && mounted) {
      showInfoSnack(
        context,
        'Suara bahasa Indonesia belum tersedia di ponsel ini. Pasang lewat '
        'Pengaturan → Bahasa → Keluaran text-to-speech.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _narration,
      builder: (context, _) {
        final speaking = _narration.isSpeaking(widget.id);
        final color = widget.onDark ? AppColors.gold : AppColors.primary;

        return OutlinedButton.icon(
          onPressed: _toggle,
          icon: Icon(
            speaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
            size: 20,
            color: color,
          ),
          label: Text(
            speaking ? 'Hentikan narasi' : 'Dengarkan kisah',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withValues(alpha: 0.6)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999)),
          ),
        );
      },
    );
  }
}
