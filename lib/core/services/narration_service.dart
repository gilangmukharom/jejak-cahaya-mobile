import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Audio narasi kisah pahlawan lewat mesin suara (TTS) bawaan ponsel.
///
/// Satu narasi berjalan pada satu waktu. [speakingId] memberi tahu tombol mana
/// yang sedang bersuara, agar tombol lain kembali ke keadaan "Dengarkan".
class NarrationService extends ChangeNotifier {
  NarrationService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _tts
      ..setCompletionHandler(_finish)
      ..setCancelHandler(_finish)
      ..setErrorHandler((_) => _finish());
  }

  final FlutterTts _tts;
  String? _speakingId;
  bool _configured = false;

  String? get speakingId => _speakingId;

  bool isSpeaking(String id) => _speakingId == id;

  /// Membacakan [text], atau menghentikannya bila [id] sedang dibacakan.
  ///
  /// Mengembalikan `false` bila ponsel tidak punya suara bahasa Indonesia —
  /// pemanggil bisa memberi tahu pemain alih-alih diam saja.
  Future<bool> toggle(String id, String text) async {
    if (_speakingId == id) {
      await stop();
      return true;
    }
    await _tts.stop();

    if (!_configured) {
      final available = await _tts.isLanguageAvailable('id-ID');
      if (available != true) return false;
      await _tts.setLanguage('id-ID');
      // Sedikit lebih lambat dari bawaan: kisahnya padat nama dan tahun.
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      _configured = true;
    }

    _speakingId = id;
    notifyListeners();
    await _tts.speak(text);
    return true;
  }

  Future<void> stop() async {
    await _tts.stop();
    _finish();
  }

  void _finish() {
    if (_speakingId == null) return;
    _speakingId = null;
    notifyListeners();
  }
}
