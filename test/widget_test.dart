import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejak_cahaya/app/theme/app_colors.dart';
import 'package:jejak_cahaya/app/theme/app_theme.dart';
import 'package:jejak_cahaya/core/error/failures.dart';
import 'package:jejak_cahaya/core/widgets/app_widgets.dart';

/// Smoke test untuk widget bersama.
///
/// Layar-layar penuh tidak diuji di sini karena semuanya bergantung pada
/// [GetIt], jaringan, dan GPS — mengujinya memerlukan test integrasi dengan
/// server tiruan, bukan widget test.
Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('FailureView menampilkan pesan dan tombol coba lagi', (
    tester,
  ) async {
    var retried = false;

    await tester.pumpWidget(
      _wrap(
        FailureView(
          failure: const NetworkFailure(message: 'Tidak ada koneksi'),
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.text('Tidak ada koneksi'), findsOneWidget);
    // Kegagalan jaringan memakai ikon wifi agar pengguna langsung mengenali
    // bahwa masalahnya ada di koneksi mereka, bukan di data.
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    expect(retried, isTrue);
  });

  testWidgets('FailureView menyembunyikan tombol saat tidak ada aksi ulang', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const FailureView(failure: UnknownFailure(message: 'Gagal')),
      ),
    );

    expect(find.text('Gagal'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('EmptyView menampilkan judul, pesan, dan aksi', (tester) async {
    await tester.pumpWidget(
      _wrap(
        EmptyView(
          icon: Icons.auto_stories_outlined,
          title: 'Koleksi masih kosong',
          message: 'Pindai QR untuk menemukan tokoh pertamamu.',
          action: FilledButton(onPressed: () {}, child: const Text('Mulai')),
        ),
      ),
    );

    expect(find.text('Koleksi masih kosong'), findsOneWidget);
    expect(find.text('Pindai QR untuk menemukan tokoh pertamamu.'),
        findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);
  });

  testWidgets('RarityBadge menampilkan warna sesuai kelangkaan',
      (tester) async {
    await tester.pumpWidget(_wrap(const RarityBadge(rarity: 'LEGENDARY')));

    expect(find.text('LEGENDARY'), findsOneWidget);

    final container = tester.widget<Container>(
      find
          .ancestor(
              of: find.text('LEGENDARY'), matching: find.byType(Container))
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, AppColors.rarityLegendary);
  });

  testWidgets('XpProgressBar membatasi nilai di luar rentang 0–1', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const XpProgressBar(progress: 1.8, label: '350 XP')),
    );

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );

    expect(indicator.value, 1.0);
    expect(find.text('350 XP'), findsOneWidget);
  });
}
