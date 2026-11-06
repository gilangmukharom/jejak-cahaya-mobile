import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejak_cahaya/core/models/enums.dart';
import 'package:jejak_cahaya/core/widgets/collectible_portrait.dart';

/// Potret tokoh.
///
/// Semua yang diuji di sini gagal tanpa suara bila rusak. `Image.asset` yang
/// menunjuk berkas tidak ada tidak melempar galat — ia hanya menyisakan ruang
/// kosong di tengah kartu. Begitu pula slug yang salah eja: potretnya tidak
/// hilang, melainkan diganti ikon, dan orang mengira memang belum ada gambarnya.

/// Slug keenam tokoh pada data seed backend.
///
/// Ditulis ulang di sini dengan sengaja: bila slug di backend berubah, tes ini
/// tetap lulus — tetapi daftar inilah yang menjadi catatan bahwa keduanya harus
/// dijaga sejalan, dan pemeriksaan aset di bawah tetap menangkap berkas yang
/// hilang atau salah nama.
const seededSlugs = <String>[
  'bilal-bin-rabah',
  'ibnu-battuta',
  'ibnu-sina',
  'muhammad-al-fatih',
  'salahuddin-al-ayyubi',
  'sunan-kalijaga',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CollectiblePortrait', () {
    for (final slug in seededSlugs) {
      test('$slug punya potret, dan berkasnya ada di bundel', () async {
        expect(
          CollectiblePortrait.hasPortrait(slug),
          isTrue,
          reason: 'slug "$slug" belum dipetakan ke berkas potret',
        );

        final data = await rootBundle.load('assets/characters/$slug.webp');
        expect(data.lengthInBytes, greaterThan(1000));
      });
    }

    testWidgets('memakai gambar untuk slug yang dikenal', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 200,
            height: 200,
            child: CollectiblePortrait(
              slug: 'ibnu-battuta',
              type: CollectibleType.character,
              rarityValue: 'EPIC',
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('jatuh ke ikon untuk slug yang tidak dikenal', (tester) async {
      // Tokoh yang ditambahkan lewat panel admin belum punya potret. Yang
      // penting: layarnya tetap utuh, bukan kosong.
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 200,
            height: 200,
            child: CollectiblePortrait(
              slug: 'tokoh-yang-belum-ada-gambarnya',
              type: CollectibleType.character,
              rarityValue: 'COMMON',
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('artefak memakai ikon museum, bukan ikon orang',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 200,
            height: 200,
            child: CollectiblePortrait(
              slug: 'artefak-tanpa-gambar',
              type: CollectibleType.artifact,
              rarityValue: 'RARE',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.museum_rounded), findsOneWidget);
    });
  });
}
