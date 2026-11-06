import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejak_cahaya/app/theme/app_colors.dart';
import 'package:jejak_cahaya/app/theme/app_theme.dart';
import 'package:jejak_cahaya/core/widgets/supported_by_pik2.dart';

/// Kredit sponsor PIK 2.
///
/// Yang diuji di sini bukan sekadar "widget-nya terbentuk", melainkan satu hal
/// yang mudah rusak tanpa disadari: keping krem di belakang logo. Logo PIK 2
/// memuat kata "DEVELOPMENT" berwarna arang, yang di atas latar hijau splash
/// hanya punya rasio kontras 1,04 : 1 — praktis tidak terlihat. Kalau suatu saat
/// kepingnya hilang karena penyederhanaan, tidak ada yang gagal dan tidak ada
/// yang error; kata itu diam-diam saja lenyap dari layar.

Widget _wrap(Widget child, {bool dark = false}) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: DecoratedBox(
          decoration: dark
              ? const BoxDecoration(gradient: AppColors.primaryGradient)
              : const BoxDecoration(color: AppColors.surface),
          child: Center(child: child),
        ),
      ),
    );

/// Keping krem yang menjadi alas logo pada latar gelap.
///
/// Pencarian dibatasi ke dalam [SupportedByPik2]. Tanpa batas itu, latar krem
/// milik pembungkus tes ini sendiri ikut terjaring dan tesnya lulus/gagal
/// karena alasan yang salah.
Finder _chip() => find.descendant(
      of: find.byType(SupportedByPik2),
      matching: find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.color == AppColors.cream;
      }),
    );

void main() {
  group('SupportedByPik2', () {
    testWidgets('memberi logo alas krem di atas latar gelap', (tester) async {
      await tester
          .pumpWidget(_wrap(const SupportedByPik2(onDark: true), dark: true));

      expect(_chip(), findsOneWidget);
    });

    testWidgets('tidak memakai alas di atas latar terang', (tester) async {
      // Di halaman profil latarnya sudah krem — keping di sana hanya menambah
      // kotak yang tidak terlihat bedanya.
      await tester.pumpWidget(_wrap(const SupportedByPik2()));

      expect(_chip(), findsNothing);
    });

    testWidgets('menampilkan label "SUPPORTED BY" dalam huruf besar',
        (tester) async {
      await tester.pumpWidget(_wrap(const SupportedByPik2()));

      expect(find.text('SUPPORTED BY'), findsOneWidget);
    });

    testWidgets('label bisa dikosongkan untuk menampilkan logo saja',
        (tester) async {
      await tester.pumpWidget(_wrap(const SupportedByPik2(label: '')));

      expect(find.byType(Text), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('logo memuat label semantik untuk pembaca layar',
        (tester) async {
      // Tanpa ini logo hanya terbaca sebagai "gambar" oleh TalkBack/VoiceOver,
      // sehingga kredit sponsornya hilang bagi pengguna yang memakainya.
      await tester.pumpWidget(_wrap(const SupportedByPik2()));

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.semanticLabel, 'PIK 2 Development');
    });

    testWidgets('memakai lebar logo yang diminta', (tester) async {
      await tester.pumpWidget(_wrap(const SupportedByPik2(logoWidth: 104)));

      expect(tester.widget<Image>(find.byType(Image)).width, 104);
    });

    test('berkas logonya benar-benar ada di dalam bundel', () async {
      // Image.asset gagal tanpa suara: berkas yang hilang atau salah nama hanya
      // menghasilkan ruang kosong di layar, bukan galat. Widget test pun tidak
      // menangkapnya, karena codec gambar tidak berjalan di dalamnya. Jadi
      // keberadaan asetnya diperiksa langsung ke bundel.
      final data = await rootBundle.load('assets/images/logo-pik-2.png');

      expect(data.lengthInBytes, greaterThan(1000));
    });
  });
}
