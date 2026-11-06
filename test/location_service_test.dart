import 'package:flutter_test/flutter_test.dart';
import 'package:jejak_cahaya/core/services/location_service.dart';

/// Perhitungan jarak & bearing di aplikasi harus identik dengan yang dipakai
/// backend (`backend/src/common/utils/geo.ts`).
///
/// Ini bukan sekadar kerapian: bila keduanya berbeda, layar bisa menampilkan
/// "sudah dekat" padahal endpoint scan menolak dengan `TOO_FAR_FROM_CHECKPOINT` —
/// pemain akan yakin aplikasinya rusak. Nilai acuan di bawah sengaja sama dengan
/// yang diuji pada `backend/tests/unit/geo.test.ts`.
void main() {
  const mosqueLat = -6.1094;
  const mosqueLon = 106.7395;

  group('distanceMeters', () {
    test('nol untuk titik yang sama', () {
      final distance = LocationService.distanceMeters(
        fromLat: mosqueLat,
        fromLon: mosqueLon,
        toLat: mosqueLat,
        toLon: mosqueLon,
      );

      expect(distance, closeTo(0, 0.001));
    });

    test('0,001° lintang ≈ 111,2 m', () {
      final distance = LocationService.distanceMeters(
        fromLat: mosqueLat,
        fromLon: mosqueLon,
        toLat: mosqueLat + 0.001,
        toLon: mosqueLon,
      );

      expect(distance, closeTo(111.2, 0.5));
    });

    test('bersifat simetris', () {
      final forward = LocationService.distanceMeters(
        fromLat: mosqueLat,
        fromLon: mosqueLon,
        toLat: -6.11,
        toLon: 106.74,
      );
      final backward = LocationService.distanceMeters(
        fromLat: -6.11,
        fromLon: 106.74,
        toLat: mosqueLat,
        toLon: mosqueLon,
      );

      expect(forward, closeTo(backward, 0.000001));
    });

    test('membedakan di dalam dan di luar radius checkpoint 25 m', () {
      // ~11 m ke utara — masih di dalam radius.
      final inside = LocationService.distanceMeters(
        fromLat: mosqueLat,
        fromLon: mosqueLon,
        toLat: mosqueLat + 0.0001,
        toLon: mosqueLon,
      );

      // ~111 m ke utara — jelas di luar radius.
      final outside = LocationService.distanceMeters(
        fromLat: mosqueLat,
        fromLon: mosqueLon,
        toLat: mosqueLat + 0.001,
        toLon: mosqueLon,
      );

      expect(inside, lessThan(25));
      expect(outside, greaterThan(25));
    });
  });

  group('bearingDegrees', () {
    test('utara ≈ 0°', () {
      final bearing = LocationService.bearingDegrees(
        fromLat: mosqueLat,
        fromLon: mosqueLon,
        toLat: mosqueLat + 0.001,
        toLon: mosqueLon,
      );

      expect(bearing, closeTo(0, 0.5));
    });

    test('timur ≈ 90°', () {
      final bearing = LocationService.bearingDegrees(
        fromLat: mosqueLat,
        fromLon: mosqueLon,
        toLat: mosqueLat,
        toLon: mosqueLon + 0.001,
      );

      expect(bearing, closeTo(90, 0.5));
    });

    test('barat ≈ 270°, selalu dalam rentang 0–360', () {
      final bearing = LocationService.bearingDegrees(
        fromLat: mosqueLat,
        fromLon: mosqueLon,
        toLat: mosqueLat,
        toLon: mosqueLon - 0.001,
      );

      expect(bearing, closeTo(270, 0.5));
      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
    });
  });

  group('PlayerPosition', () {
    test('menolak pembacaan yang akurasinya terlalu buruk', () {
      final akurat = PlayerPosition(
        latitude: mosqueLat,
        longitude: mosqueLon,
        accuracyM: 8,
        isMocked: false,
        timestamp: DateTime.now(),
      );

      final kasar = PlayerPosition(
        latitude: mosqueLat,
        longitude: mosqueLon,
        accuracyM: 250,
        isMocked: false,
        timestamp: DateTime.now(),
      );

      expect(akurat.isAccurateEnough, isTrue);
      expect(kasar.isAccurateEnough, isFalse);
    });

    test('meneruskan isMocked apa adanya ke payload scan', () {
      final position = PlayerPosition(
        latitude: mosqueLat,
        longitude: mosqueLon,
        accuracyM: 10,
        isMocked: true,
        timestamp: DateTime.now(),
      );

      // Aplikasi tidak menyembunyikan mock location; server yang memutuskan.
      expect(position.toJson()['isMocked'], isTrue);
      expect(position.toJson()['latitude'], mosqueLat);
      expect(position.toJson()['accuracyM'], 10);
    });
  });
}
