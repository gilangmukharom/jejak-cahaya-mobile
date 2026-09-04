import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

import 'location_service.dart';

/// Satu bacaan kompas: ke mana bagian atas perangkat menghadap.
class CompassReading {
  const CompassReading({required this.headingDeg, required this.accuracy});

  /// Derajat searah jarum jam dari utara magnetik, 0–360.
  final double headingDeg;

  final CompassAccuracy accuracy;
}

/// Seberapa dapat dipercaya bacaan kompas saat ini.
///
/// Bukan angka dari sistem, melainkan kesimpulan dari kuat medan magnet yang
/// terbaca: bumi menghasilkan 25–65 µT di permukaan, jadi bacaan jauh di luar
/// rentang itu berarti ada logam, magnet speaker, atau casing bermagnet di
/// dekat perangkat — dan arah yang ditunjuk kompas saat itu tidak ada
/// hubungannya dengan utara.
enum CompassAccuracy {
  good,
  needsCalibration,
  interference;

  bool get isUsable => this == CompassAccuracy.good;
}

/// Arah kiblat dan kompas yang menunjukkannya.
///
/// Dua hal digabung di sini karena keduanya tidak berguna sendirian: sudut
/// kiblat tanpa kompas hanyalah angka, dan kompas tanpa sudut kiblat hanyalah
/// penunjuk utara.
class QiblaService {
  /// Koordinat Ka'bah, Masjidil Haram.
  static const double kaabaLatitude = 21.4224779;
  static const double kaabaLongitude = 39.8251832;

  /// Sudut kiblat dari sebuah titik: derajat searah jarum jam dari utara.
  ///
  /// Ini adalah *bearing awal* lingkaran besar, bukan arah pada peta datar.
  /// Bedanya besar dan bukan kehalusan akademis: pada proyeksi Mercator, garis
  /// lurus dari Jakarta ke Makkah tampak menuju barat laut sekitar 285°,
  /// sementara arah kiblat yang benar — jalur terpendek di permukaan bola —
  /// adalah sekitar 295°.
  static double bearingFrom({
    required double latitude,
    required double longitude,
  }) =>
      LocationService.bearingDegrees(
        fromLat: latitude,
        fromLon: longitude,
        toLat: kaabaLatitude,
        toLon: kaabaLongitude,
      );

  /// Jarak ke Ka'bah dalam meter.
  static double distanceFrom({
    required double latitude,
    required double longitude,
  }) =>
      LocationService.distanceMeters(
        fromLat: latitude,
        fromLon: longitude,
        toLat: kaabaLatitude,
        toLon: kaabaLongitude,
      );

  /// Aliran arah hadap perangkat.
  ///
  /// Dirakit sendiri dari akselerometer dan magnetometer alih-alih memakai
  /// paket kompas siap pakai: yang tersedia sudah lama tidak dirawat dan gagal
  /// dibangun pada Android Gradle Plugin yang dipakai proyek ini. Rumusnya
  /// sendiri sama persis dengan `SensorManager.getRotationMatrix` di Android —
  /// akselerometer memberi tahu ke mana bawah, magnetometer memberi tahu ke
  /// mana utara, dan perkalian silang keduanya menghasilkan arah hadap.
  ///
  /// Karena akselerometer ikut dipakai, hasilnya sudah terkoreksi kemiringan:
  /// memiringkan perangkat sambil membacanya tidak membuat jarumnya berputar.
  Stream<CompassReading> get headingStream {
    late StreamController<CompassReading> controller;
    StreamSubscription<AccelerometerEvent>? accelerometer;
    StreamSubscription<MagnetometerEvent>? magnetometer;

    List<double>? gravity;
    List<double>? field;
    double? smoothed;

    void publish() {
      final g = gravity;
      final m = field;
      if (g == null || m == null) return;

      final heading = _headingFrom(gravity: g, field: m);
      if (heading == null) return;

      // Penghalus sudut. Magnetometer ponsel berderau beberapa derajat, dan
      // tanpa ini jarumnya bergetar terus-menerus di tempat — cukup untuk
      // membuat orang ragu apakah arah yang ditunjuk sudah benar.
      //
      // Interpolasinya dilakukan pada selisih terpendek, bukan pada nilai
      // mentahnya: tanpa itu, jarum yang melewati 360°→0° akan berputar
      // sepenuhnya ke arah sebaliknya.
      final previous = smoothed;
      if (previous == null) {
        smoothed = heading;
      } else {
        final delta = _shortestTurn(previous, heading);
        smoothed = _normalize(previous + delta * _smoothing);
      }

      controller.add(
        CompassReading(
          headingDeg: smoothed!,
          accuracy: _accuracyOf(m),
        ),
      );
    }

    controller = StreamController<CompassReading>.broadcast(
      onListen: () {
        accelerometer = accelerometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen(
          (event) {
            gravity = [event.x, event.y, event.z];
            publish();
          },
          onError: controller.addError,
        );

        magnetometer = magnetometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen(
          (event) {
            field = [event.x, event.y, event.z];
            publish();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await accelerometer?.cancel();
        await magnetometer?.cancel();
        accelerometer = null;
        magnetometer = null;
        gravity = null;
        field = null;
        smoothed = null;
        await controller.close();
      },
    );

    return controller.stream;
  }

  /// Bobot bacaan baru pada penghalus. Semakin kecil semakin tenang, tetapi
  /// juga semakin lambat menyusul saat perangkat benar-benar diputar.
  static const double _smoothing = 0.15;

  /// Arah hadap dari sepasang vektor, atau null bila keduanya sejajar.
  ///
  /// Sejajar berarti perangkat sedang jatuh bebas atau berada tepat di kutub
  /// magnet — pada kedua keadaan itu tidak ada arah yang bisa disimpulkan.
  static double? _headingFrom({
    required List<double> gravity,
    required List<double> field,
  }) {
    // H = medan × gravitasi → sumbu timur perangkat.
    final hx = field[1] * gravity[2] - field[2] * gravity[1];
    final hy = field[2] * gravity[0] - field[0] * gravity[2];
    final hz = field[0] * gravity[1] - field[1] * gravity[0];

    final normH = math.sqrt(hx * hx + hy * hy + hz * hz);
    if (normH < 0.1) return null;

    final invH = 1 / normH;
    final ex = hx * invH;
    final ey = hy * invH;
    final ez = hz * invH;

    final normA = math.sqrt(
      gravity[0] * gravity[0] +
          gravity[1] * gravity[1] +
          gravity[2] * gravity[2],
    );
    if (normA == 0) return null;

    final invA = 1 / normA;
    final ax = gravity[0] * invA;
    final az = gravity[2] * invA;

    // M = gravitasi × timur → sumbu utara perangkat.
    final my = az * ex - ax * ez;

    final azimuth = math.atan2(ey, my) * 180 / math.pi;
    return _normalize(azimuth);
  }

  static CompassAccuracy _accuracyOf(List<double> field) {
    final strength = math.sqrt(
      field[0] * field[0] + field[1] * field[1] + field[2] * field[2],
    );

    if (strength > 100) return CompassAccuracy.interference;
    if (strength < 20 || strength > 75) return CompassAccuracy.needsCalibration;
    return CompassAccuracy.good;
  }

  /// Selisih terpendek dari [from] ke [to], dalam rentang −180°..180°.
  static double _shortestTurn(double from, double to) =>
      (to - from + 540) % 360 - 180;

  static double _normalize(double degrees) {
    final result = degrees % 360;
    return result < 0 ? result + 360 : result;
  }

  /// Selisih antara arah hadap dan arah kiblat, −180°..180°.
  ///
  /// Nol berarti kiblat tepat di depan. Nilai positif berarti kiblat berada di
  /// sebelah kanan pengguna.
  static double offsetToQibla({
    required double headingDeg,
    required double qiblaBearingDeg,
  }) =>
      _shortestTurn(headingDeg, qiblaBearingDeg);
}
