import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejak_cahaya/core/utils/asset_url.dart';
import 'package:jejak_cahaya/features/ar/data/ar_capability.dart';

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

    test('plugin native yang tidak terpasang dianggap tidak didukung', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(await ArCapability().isSupported(), isFalse);
    });
  });
}
