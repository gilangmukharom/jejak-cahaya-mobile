import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Apakah perangkat ini bisa menampilkan tokoh dalam AR.
///
/// Jawabannya datang dari ARCore sendiri (lihat `MainActivity.kt`). Di luar
/// Android jawabannya selalu "tidak": mesin AR-nya hanya ada di Android, dan
/// di sana tokoh tetap tampil sebagai model 3D yang bisa diputar.
class ArCapability {
  ArCapability({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'id.jejakcahaya/ar_capability';

  final MethodChannel _channel;
  bool? _cached;

  Future<bool> isSupported() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    final cached = _cached;
    if (cached != null) return cached;

    try {
      var answer = await _ask();

      // "unknown" berarti ARCore masih memeriksa perangkat — biasanya hanya
      // sesaat pada pemanggilan pertama setelah pemasangan.
      for (var attempt = 0; answer == 'unknown' && attempt < 6; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        answer = await _ask();
      }

      final supported = answer == 'supported';
      // "unknown" dan "timeout" tidak disimpan: lain kali ditanya ulang,
      // karena ARCore mungkin sudah selesai memeriksa.
      if (answer == 'supported' || answer == 'unsupported') _cached = supported;
      return supported;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Satu pertanyaan ke ARCore, dibatasi waktunya: bila jawabannya tidak
  /// pernah datang, pemanggil tidak boleh ikut menunggu selamanya.
  Future<String?> _ask() => _channel
      .invokeMethod<String>('checkAvailability')
      .timeout(askTimeout, onTimeout: () => 'timeout');

  /// Batas satu pertanyaan ke ARCore.
  @visibleForTesting
  static Duration askTimeout = const Duration(seconds: 4);

  /// Dipanggil bila sesi AR ternyata tidak bisa berjalan meski ARCore
  /// mengaku mendukung, agar layar berikutnya langsung memakai tampilan 3D.
  void markUnsupported() => _cached = false;
}
