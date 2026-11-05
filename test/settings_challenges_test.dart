import 'package:flutter_test/flutter_test.dart';
import 'package:nusaverse/core/models/challenge.dart';
import 'package:nusaverse/core/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppSettings', () {
    test('nilai bawaan: AR menyala, mode lain mati', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings(await SharedPreferences.getInstance());

      expect(settings.arEnabled, isTrue);
      expect(settings.largeText, isFalse);
      expect(settings.batterySaver, isFalse);
      expect(settings.familyMode, isFalse);
    });

    test('perubahan tersimpan dan mengabari pendengar', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);
      var notified = 0;
      settings.addListener(() => notified++);

      await settings.setFamilyMode(value: true);
      await settings.setArEnabled(value: false);

      expect(notified, 2);
      // Dibaca ulang dari penyimpanan, bukan dari memori.
      final reloaded = AppSettings(prefs);
      expect(reloaded.familyMode, isTrue);
      expect(reloaded.arEnabled, isFalse);
    });
  });

  group('Challenge', () {
    Challenge parse(Map<String, dynamic> overrides) => Challenge.fromJson({
          'id': 'c1',
          'title': 'Hero Hari Ini',
          'description': 'Temukan 1 hero hari ini.',
          'period': 'DAILY',
          'target': 1,
          'progress': 0,
          'pointsReward': 50,
          'xpReward': 20,
          'isComplete': false,
          'isClaimed': false,
          'endsAt': '2026-11-05T17:00:00.000Z',
          ...overrides,
        });

    test('bisa diklaim hanya bila selesai dan belum diklaim', () {
      expect(parse({}).canClaim, isFalse);
      expect(parse({'progress': 1, 'isComplete': true}).canClaim, isTrue);
      expect(parse({'progress': 1, 'isComplete': true, 'isClaimed': true}).canClaim, isFalse);
    });

    test('rasio kemajuan dibatasi 0–1 dan periode dikenali', () {
      final weekly = parse({'period': 'WEEKLY', 'target': 5, 'progress': 2});
      expect(weekly.period, ChallengePeriod.weekly);
      expect(weekly.ratio, closeTo(0.4, 0.001));
      expect(parse({'target': 3, 'progress': 9}).ratio, 1);
    });

    test('tantangan umum tidak punya titik maupun langkah', () {
      final general = parse({'scope': 'GLOBAL', 'checkpoint': null, 'steps': null});
      expect(general.isCheckpoint, isFalse);
      expect(general.steps, isNull);
    });

    test('tantangan titik membawa titik, lokasi, dan langkahnya', () {
      final challenge = parse({
        'scope': 'CHECKPOINT',
        'period': 'WEEKLY',
        'target': 2,
        'progress': 1,
        'checkpoint': {
          'id': 'cp1',
          'code': 'TPR-01',
          'name': 'Halaman Tugu',
          'siteId': 's1',
          'siteName': 'Tugu Proklamasi',
          'collectibleId': 'h1',
          'collectibleName': 'Ir. Soekarno',
          'rarity': 'LEGENDARY',
        },
        'steps': {'visited': true, 'quizPassed': false},
      });
      expect(challenge.isCheckpoint, isTrue);
      expect(challenge.checkpoint!.siteName, 'Tugu Proklamasi');
      expect(challenge.checkpoint!.rarity, 'LEGENDARY');
      expect(challenge.steps!.visited, isTrue);
      expect(challenge.steps!.quizPassed, isFalse);
    });

    test('titik tanpa kuis: quizPassed null', () {
      final challenge = parse({
        'checkpoint': {'id': 'cp1', 'code': 'G-01', 'siteName': 'GSO'},
        'steps': {'visited': false, 'quizPassed': null},
      });
      expect(challenge.steps!.quizPassed, isNull);
    });
  });
}
