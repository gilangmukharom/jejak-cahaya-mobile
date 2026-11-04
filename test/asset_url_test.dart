import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejak_cahaya/core/utils/asset_url.dart';
import 'package:jejak_cahaya/features/ar/data/ar_capability.dart';
import 'package:jejak_cahaya/features/ar/data/model_cache.dart';

void main() {
  group('resolveBackendAssetUrl', () {
    test('jalur relatif menggantikan prefix /api/v1 pada alamat API', () {
      expect(
        resolveBackendAssetUrl(
          '/static/models/soekarno.glb',
          apiBaseUrl: 'http://10.0.2.2:3000/api/v1',
        ),
        'http://10.0.2.2:3000/static/models/soekarno.glb',
      );
    });

    test('mengikuti domain produksi tanpa port', () {
      expect(
        resolveBackendAssetUrl(
          '/static/models/soekarno.glb',
          apiBaseUrl: 'https://api.contoh.id/api/v1',
        ),
        'https://api.contoh.id/static/models/soekarno.glb',
      );
    });

    test('URL absolut (CDN) dikembalikan apa adanya', () {
      const cdn = 'https://cdn.contoh.id/models/bilal.glb';
      expect(
        resolveBackendAssetUrl(cdn, apiBaseUrl: 'http://10.0.2.2:3000/api/v1'),
        cdn,
      );
    });
  });

  group('ModelCache.bundledAssetFor', () {
    test('soekarno.glb dari server dibaca dari APK, tanpa unduhan', () {
      expect(
        ModelCache.bundledAssetFor('/static/models/soekarno.glb'),
        'assets/models/soekarno.glb',
      );
      // Alamat lengkap (mis. bila suatu saat disimpan absolut) juga dikenali.
      expect(
        ModelCache.bundledAssetFor(
          'https://api.jejak-cahaya.com/static/models/soekarno.glb',
        ),
        'assets/models/soekarno.glb',
      );
    });

    test('model unggahan admin tetap diunduh', () {
      expect(ModelCache.bundledAssetFor('/static/models/bilal.glb'), isNull);
      expect(
        ModelCache.bundledAssetFor('/static/models/soekarno-v2.glb'),
        isNull,
      );
      expect(
        ModelCache.bundledAssetFor('https://cdn.contoh.id/soekarno.glb'),
        isNull,
      );
    });

    test('setiap model bawaan benar-benar ada di bundel', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final asset in ModelCache.bundledModels.values) {
        final data = await rootBundle.load(asset);
        // GLB diawali "glTF".
        expect(
          String.fromCharCodes(data.buffer.asUint8List(data.offsetInBytes, 4)),
          'glTF',
          reason: asset,
        );
      }
    });
  });

  group('ArCapability', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('selalu tidak didukung di luar Android tanpa bertanya ke native', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(await ArCapability().isSupported(), isFalse);
    });

    test('menunggu ARCore selesai memeriksa saat jawabannya "unknown"', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      const channel = MethodChannel(ArCapability.channelName);
      final answers = ['unknown', 'unknown', 'supported'];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => answers.removeAt(0));
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      expect(await ArCapability().isSupported(), isTrue);
      expect(answers, isEmpty);
    });

    test('ARCore yang tidak pernah menjawab tidak menggantung layar AR', () async {
      // Reproduksi bug "loading mentok di 100%": jawaban native tidak pernah
      // datang, dan sebelumnya pemanggil ikut menunggu selamanya.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final previousTimeout = ArCapability.askTimeout;
      ArCapability.askTimeout = const Duration(milliseconds: 50);
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        ArCapability.askTimeout = previousTimeout;
      });

      const channel = MethodChannel(ArCapability.channelName);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) => Completer<String>().future);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final capability = ArCapability();
      expect(await capability.isSupported(), isFalse);

      // Hasil timeout tidak disimpan: begitu ARCore menjawab, AR dipakai.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => 'supported');
      expect(await capability.isSupported(), isTrue);
    });

    test('plugin native yang tidak terpasang dianggap tidak didukung', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(await ArCapability().isSupported(), isFalse);
    });
  });
}
