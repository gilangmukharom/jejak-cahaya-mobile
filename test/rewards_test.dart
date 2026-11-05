import 'package:flutter_test/flutter_test.dart';
import 'package:nusaverse/core/models/reward.dart';
import 'package:nusaverse/core/models/scan_result.dart';
import 'package:nusaverse/core/models/user.dart';
import 'package:nusaverse/features/rewards/presentation/widgets/points_badge.dart';

void main() {
  group('Reward Store model', () {
    test('membaca katalog beserta saldo', () {
      final catalog = RewardCatalog.fromJson(const {
        'balance': 1250,
        'rewards': [
          {
            'id': 'r1',
            'name': 'Kaos NUSAVERSE',
            'description': 'Kaos katun',
            'category': 'MERCHANDISE',
            'pointsCost': 2500,
            'stock': 0,
            'isAvailable': false,
            'howToClaim': 'Tunjukkan kode ke petugas.',
          },
          {
            'id': 'r2',
            'name': 'Bingkai Avatar',
            'description': 'Item digital',
            'category': 'DIGITAL',
            'pointsCost': 150,
            'stock': null,
            'isAvailable': true,
          },
        ],
      });

      expect(catalog.balance, 1250);
      expect(catalog.rewards.first.isOutOfStock, isTrue);
      expect(catalog.rewards.last.stock, isNull);
      expect(catalog.rewards.last.isOutOfStock, isFalse);
      expect(catalog.rewards.last.category, RewardCategory.digital);
    });

    test('kategori dan status yang tidak dikenal tidak membuat crash', () {
      expect(RewardCategory.parse('NFT'), RewardCategory.merchandise);
      expect(RedemptionStatus.parse(null), RedemptionStatus.pending);
    });

    test('membaca penukaran beserta kode dan cara mengambilnya', () {
      final redemption = Redemption.fromJson(const {
        'id': 'x1',
        'code': 'NV-7K2QX9MA',
        'status': 'FULFILLED',
        'pointsSpent': 300,
        'createdAt': '2026-11-05T10:00:00.000Z',
        'reward': {
          'name': 'Stiker Pack',
          'category': 'MERCHANDISE',
          'howToClaim': 'Di meja event'
        },
      });

      expect(redemption.code, 'NV-7K2QX9MA');
      expect(redemption.status, RedemptionStatus.fulfilled);
      expect(redemption.howToClaim, 'Di meja event');
    });
  });

  group('NUSA POINTS', () {
    test('rincian poin scan dijumlahkan dari setiap sumbernya', () {
      final points = ScanPoints.fromJson(
          const {'discovery': 500, 'locationVisit': 100, 'mission': 400});
      expect(points.total, 1000);
    });

    test('respons lama tanpa field poin dibaca sebagai nol', () {
      expect(ScanPoints.fromJson(const {}).total, 0);
      final user = User.fromJson(const {'id': 'u', 'totalXp': 10});
      expect(user.nusaPoints, 0);
    });

    test('angka poin memakai pemisah ribuan Indonesia', () {
      expect(formatPoints(12500), '12.500');
      expect(formatPoints(50), '50');
    });
  });
}
