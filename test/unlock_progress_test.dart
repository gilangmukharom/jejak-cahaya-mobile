import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejak_cahaya/app/theme/app_theme.dart';
import 'package:jejak_cahaya/core/models/scan_result.dart';
import 'package:jejak_cahaya/core/widgets/unlock_progress.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

const _next = NextCheckpoint(
  code: 'AIK-14',
  name: 'Ruang Bedug',
  playOrder: 2,
  missionTitle: 'Mengenal Rumah Allah',
  hint: 'Cari QR di tiang penyangga bedug.',
);

void main() {
  group('UnlockProgress', () {
    testWidgets(
        'menampilkan titik yang terbuka dan titik berikutnya yang masih '
        'tergembok', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UnlockProgress(
            unlockedLabel: 'Mihrab',
            progress: (discovered: 1, total: 14),
            nextCheckpoint: _next,
          ),
        ),
      );

      // Animasinya berjalan 2 detik; dijalankan sampai tuntas agar kartu
      // "berikutnya" — yang baru muncul di 72 % durasi — sempat tergambar.
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('TERBUKA'), findsOneWidget);
      expect(find.text('Mihrab'), findsOneWidget);
      expect(find.text('1 dari 14 titik ditemukan'), findsOneWidget);

      // Inti permintaannya: langkah berikutnya diberitahukan, tapi tergembok.
      expect(find.text('BERIKUTNYA · TITIK 2'), findsOneWidget);
      expect(find.text('Ruang Bedug'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('menampilkan petunjuk lokasi titik berikutnya', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UnlockProgress(
            unlockedLabel: 'Mihrab',
            progress: (discovered: 1, total: 14),
            nextCheckpoint: _next,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Cari QR di tiang penyangga bedug.'), findsOneWidget);
    });

    testWidgets('merayakan penyelesaian saat tidak ada titik tersisa', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const UnlockProgress(
            unlockedLabel: 'Syekh Yusuf Al-Makassari',
            progress: (discovered: 14, total: 14),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.textContaining('Barakallahu fiik'), findsOneWidget);
    });

    testWidgets('tidak membagi dengan nol saat total masih kosong', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const UnlockProgress(
            unlockedLabel: 'Mihrab',
            progress: (discovered: 0, total: 0),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(tester.takeException(), isNull);
      expect(find.text('0 dari 0 titik ditemukan'), findsOneWidget);
    });
  });

  group('NextCheckpoint', () {
    test('mem-parsing muatan dari endpoint scan', () {
      final next = NextCheckpoint.fromJson(const {
        'code': 'AIK-01',
        'name': 'Menara Azan',
        'hint': 'Dekat pangkal menara.',
        'playOrder': 3,
        'missionTitle': 'Jejak Para Sahabat',
      });

      expect(next.code, 'AIK-01');
      expect(next.playOrder, 3);
      expect(next.hint, 'Dekat pangkal menara.');
    });

    test('tetap utuh meski petunjuknya kosong', () {
      final next = NextCheckpoint.fromJson(const {
        'code': 'AIK-02',
        'name': 'Taman Sisi Utara',
        'playOrder': 4,
        'missionTitle': 'Jejak Para Sahabat',
      });

      expect(next.hint, isNull);
      expect(next.name, 'Taman Sisi Utara');
    });
  });
}
