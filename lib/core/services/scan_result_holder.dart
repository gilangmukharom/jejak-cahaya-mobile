import 'dart:async';

import '../models/scan_result.dart';

/// Menyimpan hasil scan terakhir dan mengabarkan setiap penemuan baru.
///
/// **Menyimpan hasil.** Sebelumnya hasil scan dikirim lewat `extra` milik
/// go_router. Itu rapuh: `refreshListenable` pada router ikut memicu pembacaan
/// ulang rute, dan ketika `extra` tidak terbawa, builder rute jatuh ke halaman
/// cadangan — layar penemuan berkedip sebentar lalu tergantikan sendiri.
/// Menyimpannya di sini membuat halaman penemuan kebal terhadap berapa kali pun
/// rutenya dibangun ulang.
///
/// **Mengabarkan penemuan.** Tab pada [StatefulShellRoute] mempertahankan
/// state-nya, jadi kembali ke peta setelah scan tidak membangun ulang apa pun —
/// dan cubit yang sudah ada tetap memegang data lama. Akibatnya progres masih
/// menunjukkan angka sebelum penemuan. [onDiscovery] memberi tahu cubit yang
/// sedang hidup bahwa datanya sudah basi dan perlu diambil ulang.
class ScanResultHolder {
  ScanResult? _lastResult;

  final StreamController<ScanResult> _discoveries =
      StreamController<ScanResult>.broadcast();

  ScanResult? get lastResult => _lastResult;

  /// Dipancarkan setiap kali sebuah penemuan baru berhasil diklaim.
  Stream<ScanResult> get onDiscovery => _discoveries.stream;

  /// Nilainya sengaja tidak dibersihkan saat halaman penemuan ditutup —
  /// menimpanya pada scan berikutnya sudah cukup, dan membersihkannya justru
  /// berisiko mengosongkan layar yang sedang dibaca pemain.
  void save(ScanResult result) {
    _lastResult = result;
    if (!_discoveries.isClosed) _discoveries.add(result);
  }

  Future<void> dispose() => _discoveries.close();
}
