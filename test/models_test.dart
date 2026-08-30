import 'package:flutter_test/flutter_test.dart';
import 'package:jejak_cahaya/core/models/collectible.dart';
import 'package:jejak_cahaya/core/models/enums.dart';
import 'package:jejak_cahaya/core/models/json_utils.dart';

void main() {
  group('Json helper', () {
    test('menerima int yang datang sebagai double', () {
      // PostgreSQL lewat Prisma kadang mengirim bilangan bulat sebagai 100.0.
      expect(Json.integer(100.0), 100);
      expect(Json.integer('42'), 42);
      expect(Json.integer(null, 7), 7);
    });

    test('mengembalikan nilai bawaan alih-alih melempar pada tipe tak terduga',
        () {
      expect(Json.str(12345), '');
      expect(Json.decimal({'bukan': 'angka'}), 0);
      expect(Json.boolean('true'), isFalse);
      expect(Json.stringList('bukan list'), isEmpty);
    });

    test('melewati elemen yang bukan objek saat memetakan daftar', () {
      final result = Json.list(
        [
          {'id': 'a'},
          'sampah',
          42,
          {'id': 'b'},
        ],
        (json) => Json.str(json['id']),
      );

      expect(result, ['a', 'b']);
    });
  });

  group('Enum parsing', () {
    test('memetakan nilai backend yang dikenal', () {
      expect(Rarity.parse('LEGENDARY'), Rarity.legendary);
      expect(CollectibleCategory.parse('COMPANION'),
          CollectibleCategory.companion);
      expect(CollectibleType.parse('ARTIFACT'), CollectibleType.artifact);
    });

    test('nilai tak dikenal menjadi unknown, bukan exception', () {
      // Kurator bisa menambah kategori baru sewaktu-waktu; aplikasi versi lama
      // harus tetap dapat menampilkan daftarnya.
      expect(Rarity.parse('MYTHIC'), Rarity.unknown);
      expect(CollectibleCategory.parse(null), CollectibleCategory.unknown);
    });
  });

  group('Collectible', () {
    Map<String, dynamic> payload({required bool discovered}) => {
          'id': 'c-1',
          'slug': 'salahuddin-al-ayyubi',
          'type': 'CHARACTER',
          'category': 'LEADER',
          'rarity': 'RARE',
          'name': 'Salahuddin Al-Ayyubi',
          'title': 'Sang Pembebas Al-Quds',
          'summary': 'Pemimpin muslim pada masa Perang Salib.',
          'story': discovered ? 'Kisah panjang…' : null,
          'xpReward': 100,
          'isDiscovered': discovered,
        };

    test('membuka kisah untuk item yang sudah ditemukan', () {
      final collectible = Collectible.fromJson(payload(discovered: true));

      expect(collectible.isDiscovered, isTrue);
      expect(collectible.story, isNotNull);
      expect(collectible.rarity, Rarity.rare);
    });

    test('kisah tetap null untuk item yang belum ditemukan', () {
      // Backend menahan `story` sampai pemain benar-benar menemukannya; model
      // harus memperlakukan null di sini sebagai "terkunci", bukan data rusak.
      final collectible = Collectible.fromJson(payload(discovered: false));

      expect(collectible.isDiscovered, isFalse);
      expect(collectible.story, isNull);
      expect(collectible.summary, isNotEmpty);
      expect(collectible.name, 'Salahuddin Al-Ayyubi');
    });
  });

  group('CollectionProgress', () {
    test('menghitung rasio per kategori', () {
      final progress = CollectionProgress.fromJson(const {
        'owned': 7,
        'total': 14,
        'completionRate': 50.0,
        'byCategory': {
          'COMPANION': {'owned': 2, 'total': 2},
          'SCHOLAR': {'owned': 1, 'total': 3},
        },
        'byRarity': <String, dynamic>{},
      });

      expect(progress.owned, 7);
      expect(progress.byCategory['COMPANION']!.isComplete, isTrue);
      expect(progress.byCategory['SCHOLAR']!.ratio, closeTo(0.333, 0.01));
    });

    test('tidak membagi dengan nol saat katalog masih kosong', () {
      const empty = CollectionProgress.empty;

      expect(empty.completionRate, 0);
      expect(empty.byCategory, isEmpty);
    });
  });
}
