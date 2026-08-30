import 'package:flutter_test/flutter_test.dart';
import 'package:jejak_cahaya/core/models/scan_result.dart';
import 'package:jejak_cahaya/core/services/scan_result_holder.dart';

/// Mengunci perilaku yang memperbaiki bug "layar penemuan tertutup sendiri".
///
/// Hasil scan dulu dikirim lewat `extra` milik go_router dan hilang ketika
/// router menyegarkan diri. Holder ini harus mengembalikan hasil yang sama
/// berapa kali pun dibaca, karena builder rute membacanya ulang pada setiap
/// pembangunan ulang.
ScanResult _scanResult({required String name}) => ScanResult.fromJson({
      'discovery': const {
        'id': 'd-1',
        'discoveredAt': '2026-08-30T10:00:00.000Z',
        'distanceM': 8.2,
        'xpEarned': 100,
      },
      'collectible': {
        'id': 'c-1',
        'slug': 'salahuddin-al-ayyubi',
        'type': 'CHARACTER',
        'category': 'LEADER',
        'rarity': 'RARE',
        'name': name,
        'summary': 'Ringkasan.',
        'story': 'Kisah lengkap.',
        'xpReward': 100,
        'isDiscovered': true,
      },
      'checkpoint': const {
        'id': 'cp-1',
        'code': 'AIK-01',
        'name': 'Serambi Utama'
      },
      'hasQuiz': true,
      'quizId': 'q-1',
      'totalXp': 350,
      'missionCompleted': false,
      'unlockedAchievements': const <dynamic>[],
    });

void main() {
  group('ScanResultHolder', () {
    test('kosong sebelum ada scan', () {
      expect(ScanResultHolder().lastResult, isNull);
    });

    test('mengembalikan hasil yang sama pada pembacaan berulang', () {
      final holder = ScanResultHolder()..save(_scanResult(name: 'Salahuddin'));

      // Builder rute membaca ulang setiap kali router menyegarkan diri;
      // pembacaan kedua tidak boleh mengosongkan hasilnya.
      expect(holder.lastResult?.collectible.name, 'Salahuddin');
      expect(holder.lastResult?.collectible.name, 'Salahuddin');
      expect(holder.lastResult?.xpEarned, 100);
      expect(holder.lastResult?.quizId, 'q-1');
    });

    test('scan berikutnya menimpa hasil sebelumnya', () {
      final holder = ScanResultHolder()..save(_scanResult(name: 'Bilal'));
      expect(holder.lastResult?.collectible.name, 'Bilal');

      holder.save(_scanResult(name: 'Ibnu Sina'));
      expect(holder.lastResult?.collectible.name, 'Ibnu Sina');
    });
  });

  group('ScanResult', () {
    test('membawa id quiz agar layar penemuan bisa menautkannya', () {
      final result = _scanResult(name: 'Salahuddin');

      expect(result.hasQuiz, isTrue);
      expect(result.quizId, isNotNull);
      expect(result.checkpointName, 'Serambi Utama');
    });
  });
}
