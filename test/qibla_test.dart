import 'package:flutter_test/flutter_test.dart';
import 'package:jejak_cahaya/core/services/qibla_service.dart';
import 'package:jejak_cahaya/core/utils/distance.dart';
import 'package:jejak_cahaya/core/utils/id_date.dart';

/// Arah kiblat adalah bearing awal lingkaran besar menuju Ka'bah — bukan arah
/// pada peta datar. Bedanya sepuluh derajat penuh jika dilihat dari Indonesia,
/// cukup untuk membuat saf melenceng beberapa meter di ujung ruangan, jadi
/// nilainya diuji terhadap sudut yang sudah lazim dipakai di kota-kota berikut.
void main() {
  group('sudut kiblat', () {
    // Sudut acuan mengikuti angka yang lazim dipakai jadwal kiblat kota-kota
    // ini. Toleransi setengah derajat jauh lebih ketat daripada ketelitian
    // kompas ponsel mana pun, jadi kegagalan di sini berarti rumusnya berubah,
    // bukan sekadar pembulatan yang bergeser.
    const places = <String, (double, double, double)>{
      'Jakarta': (-6.1754, 106.8272, 295.1),
      'Surabaya': (-7.2575, 112.7521, 294.0),
      'Banda Aceh': (5.5483, 95.3238, 292.6),
      'Makassar': (-5.1477, 119.4327, 292.6),
    };

    places.forEach((city, value) {
      final (latitude, longitude, expected) = value;

      test('$city menghadap sekitar ${expected.round()} derajat', () {
        final bearing = QiblaService.bearingFrom(
          latitude: latitude,
          longitude: longitude,
        );

        expect(bearing, closeTo(expected, 0.5));
      });
    });

    test('titik tepat di Kabah tidak menghasilkan nilai tak hingga', () {
      final bearing = QiblaService.bearingFrom(
        latitude: QiblaService.kaabaLatitude,
        longitude: QiblaService.kaabaLongitude,
      );

      expect(bearing.isFinite, isTrue);
      expect(bearing, inInclusiveRange(0, 360));
    });

    test('jarak Jakarta ke Kabah sekitar 7.900 km', () {
      final meters = QiblaService.distanceFrom(
        latitude: -6.1754,
        longitude: 106.8272,
      );

      expect(meters / 1000, closeTo(7900, 60));
    });
  });

  group('selisih terhadap arah hadap', () {
    test('nol ketika perangkat sudah menghadap kiblat', () {
      expect(
        QiblaService.offsetToQibla(headingDeg: 295, qiblaBearingDeg: 295),
        0,
      );
    });

    test('positif berarti kiblat berada di sebelah kanan', () {
      expect(
        QiblaService.offsetToQibla(headingDeg: 270, qiblaBearingDeg: 295),
        closeTo(25, 0.001),
      );
    });

    test('memilih putaran terpendek saat melewati utara', () {
      // Dari 350° ke 10° hanya 20° ke kanan, bukan 340° ke kiri. Tanpa
      // penanganan ini, layar akan menyuruh orang berputar hampir satu
      // lingkaran penuh untuk menghadap arah yang praktis sama.
      expect(
        QiblaService.offsetToQibla(headingDeg: 350, qiblaBearingDeg: 10),
        closeTo(20, 0.001),
      );

      expect(
        QiblaService.offsetToQibla(headingDeg: 10, qiblaBearingDeg: 350),
        closeTo(-20, 0.001),
      );
    });

    test('selalu berada dalam rentang setengah lingkaran', () {
      for (var heading = 0; heading < 360; heading += 7) {
        final offset = QiblaService.offsetToQibla(
          headingDeg: heading.toDouble(),
          qiblaBearingDeg: 295.1,
        );

        expect(offset, inInclusiveRange(-180, 180), reason: 'hadap $heading');
      }
    });
  });

  group('format', () {
    test('jarak memakai meter di bawah satu kilometer', () {
      expect(formatDistance(0), '0 m');
      expect(formatDistance(248.4), '248 m');
      expect(formatDistance(999), '999 m');
    });

    test('jarak memakai koma sebagai pemisah desimal', () {
      expect(formatDistance(1000), '1,0 km');
      expect(formatDistance(3420), '3,4 km');
    });

    test('desimal dilepas begitu jaraknya dua digit kilometer', () {
      expect(formatDistance(12300), '12 km');
      expect(formatDistance(7900000), '7900 km');
    });

    test('jam ditulis dua digit', () {
      expect(formatClock(DateTime(2026, 9, 4, 4, 7)), '04:07');
      expect(formatClock(DateTime(2026, 9, 4, 17, 54)), '17:54');
    });

    test('tanggal panjang memakai nama hari dan bulan Indonesia', () {
      expect(formatLongDate(DateTime(2026, 9, 4)), 'Jumat, 4 September 2026');
      expect(formatLongDate(DateTime(2026, 1, 5)), 'Senin, 5 Januari 2026');
    });

    test('hitung mundur mengganti satuan sesuai sisa waktunya', () {
      expect(
        formatCountdown(const Duration(hours: 2, minutes: 14, seconds: 9)),
        '2 jam 14 menit',
      );
      expect(
        formatCountdown(const Duration(minutes: 8, seconds: 30)),
        '8 menit 30 detik',
      );
      expect(formatCountdown(const Duration(seconds: 12)), '12 detik');

      // Waktu yang sudah lewat dijepit ke nol, bukan ditampilkan negatif.
      expect(formatCountdown(const Duration(seconds: -5)), '0 detik');
    });
  });
}
