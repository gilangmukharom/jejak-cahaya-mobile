import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nusaverse/core/models/enums.dart';
import 'package:nusaverse/core/widgets/collectible_portrait.dart';

/// Potret Hero Card.
///
/// Semua yang diuji di sini gagal tanpa suara bila rusak. `Image.asset` yang
/// menunjuk berkas tidak ada tidak melempar galat — ia hanya menyisakan ruang
/// kosong di tengah kartu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CollectiblePortrait', () {
    test('setiap potret yang dipetakan benar-benar ada di bundel', () async {
      for (final asset in CollectiblePortrait.mappedAssets) {
        final data = await rootBundle.load(asset);
        expect(data.lengthInBytes, greaterThan(1000), reason: asset);
      }
    });

    testWidgets('pahlawan tanpa potret tetap tampil dengan ikon',
        (tester) async {
      // Pahlawan NUSAVERSE belum punya potret; kartunya tidak boleh kosong.
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 200,
            height: 200,
            child: CollectiblePortrait(
              slug: 'soekarno',
              type: CollectibleType.character,
              rarityValue: 'LEGENDARY',
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('pahlawan bernama tanpa potret tampil sebagai monogram inisial',
        (tester) async {
      Future<void> pump(String name) => tester.pumpWidget(
            MaterialApp(
              home: SizedBox(
                width: 200,
                height: 200,
                child: CollectiblePortrait(
                  slug: 'x',
                  name: name,
                  type: CollectibleType.character,
                  rarityValue: 'EPIC',
                ),
              ),
            ),
          );

      // Gelar seperti "Drs." dan "Ir." diabaikan.
      await pump('Drs. Mohammad Hatta');
      expect(find.text('MH'), findsOneWidget);
      await pump('Ir. Soekarno');
      expect(find.text('S'), findsOneWidget);
      await pump('R.A. Kartini');
      expect(find.text('K'), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsNothing);
    });

    testWidgets('situs bersejarah memakai ikon museum, bukan ikon orang',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 200,
            height: 200,
            child: CollectiblePortrait(
              slug: 'situs-tanpa-gambar',
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
