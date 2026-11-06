import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../config/app_config.dart';
import '../error/failures.dart';

/// Pembacaan posisi beserta informasi yang dibutuhkan backend untuk memvalidasi
/// sebuah scan.
class PlayerPosition {
  const PlayerPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.isMocked,
    required this.timestamp,
    this.headingDeg,
    this.speedMps = 0,
  });

  final double latitude;
  final double longitude;
  final double accuracyM;

  /// True bila sistem operasi melaporkan bahwa posisi ini berasal dari aplikasi
  /// lokasi palsu. Diteruskan apa adanya ke backend, yang mengambil keputusan.
  final bool isMocked;

  final DateTime timestamp;

  /// Arah gerak pemain dalam derajat, 0° = utara. Null bila belum diketahui.
  ///
  /// Ini adalah *course over ground* dari GPS — arah pemain berpindah — bukan
  /// bacaan kompas magnetik. Bedanya penting: nilainya hanya bermakna selama
  /// pemain benar-benar berjalan, dan tidak berubah ketika pemain berdiri diam
  /// lalu memutar badan. Peta memakainya untuk berputar mengikuti pemain, dan
  /// menahan putaran itu saat [isMoving] bernilai false — lihat [headingWhenMoving].
  final double? headingDeg;

  /// Laju pemain dalam meter/detik menurut GPS.
  final double speedMps;

  factory PlayerPosition.fromGeolocator(Position position) => PlayerPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy,
        isMocked: position.isMocked,
        timestamp: position.timestamp,
        // Geolocator melaporkan nilai negatif ketika arah tidak tersedia.
        headingDeg: position.heading < 0 ? null : position.heading % 360,
        speedMps: position.speed < 0 ? 0 : position.speed,
      );

  /// Apakah pembacaan ini cukup presisi untuk dipakai memindai.
  bool get isAccurateEnough => accuracyM <= AppConfig.maxGpsAccuracyM;

  /// Apakah pemain sedang benar-benar berpindah tempat.
  ///
  /// Ambangnya berada di bawah kecepatan jalan santai (±1,3 m/s) tetapi di atas
  /// derau GPS saat diam, yang kerap menghasilkan laju semu beberapa desimeter
  /// per detik.
  bool get isMoving => speedMps >= _movingThresholdMps;

  /// Arah hadap yang layak dipakai memutar peta, atau null saat pemain diam.
  ///
  /// Tanpa penjagaan ini peta akan berputar-putar sendiri ketika pemain berhenti
  /// membaca kisah tokoh — derau GPS membuat arah gerak melompat ke segala
  /// penjuru justru ketika perpindahannya nol.
  double? get headingWhenMoving => isMoving ? headingDeg : null;

  static const double _movingThresholdMps = 0.6;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracyM': accuracyM,
        'isMocked': isMocked,
      };
}

/// Akses lokasi perangkat: izin, pembacaan sekali, dan aliran pembaruan.
///
/// Seluruh keputusan permainan tetap diambil server. Kelas ini hanya bertugas
/// menyediakan koordinat yang jujur — termasuk melaporkan `isMocked` apa adanya
/// alih-alih menyembunyikannya.
class LocationService {
  StreamSubscription<Position>? _subscription;
  final StreamController<PlayerPosition> _controller =
      StreamController<PlayerPosition>.broadcast();

  PlayerPosition? _lastKnown;

  /// Posisi terakhir yang diketahui, bila ada.
  PlayerPosition? get lastKnown => _lastKnown;

  /// Aliran pembaruan posisi. Mulai memancarkan setelah [startTracking].
  Stream<PlayerPosition> get positionStream => _controller.stream;

  LocationSettings get _settings => const LocationSettings(
        // `best` menguras baterai lebih cepat, tetapi radius checkpoint hanya
        // 25 m — akurasi sedang membuat pemain tertolak padahal sudah berdiri
        // tepat di depan QR.
        accuracy: LocationAccuracy.best,
        distanceFilter: AppConfig.locationDistanceFilterM,
      );

  /// Memastikan layanan lokasi menyala dan izin sudah diberikan.
  ///
  /// Melempar [LocationFailure] dengan pesan yang siap ditampilkan, termasuk
  /// menandai kasus "ditolak permanen" — satu-satunya jalan keluar dari kondisi
  /// itu adalah membuka pengaturan sistem, bukan meminta izin ulang.
  Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
        message: 'Layanan lokasi mati. Aktifkan GPS untuk mulai menjelajah.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        message:
            'Izin lokasi ditolak permanen. Buka Pengaturan aplikasi untuk mengizinkannya.',
        isPermanentlyDenied: true,
      );
    }

    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
        message:
            'Izin lokasi diperlukan agar aplikasi dapat mendeteksi checkpoint.',
      );
    }
  }

  /// Membaca posisi terkini satu kali.
  Future<PlayerPosition> getCurrentPosition() async {
    await ensurePermission();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _settings,
      ).timeout(const Duration(seconds: 20));

      final result = PlayerPosition.fromGeolocator(position);
      _lastKnown = result;
      return result;
    } on TimeoutException {
      throw const LocationFailure(
        message:
            'Gagal mendapatkan sinyal GPS. Coba pindah ke area yang lebih terbuka.',
      );
    }
  }

  /// Mulai memancarkan pembaruan posisi ke [positionStream].
  Future<void> startTracking() async {
    if (_subscription != null) return;

    await ensurePermission();

    _subscription =
        Geolocator.getPositionStream(locationSettings: _settings).listen(
      (position) {
        final result = PlayerPosition.fromGeolocator(position);
        _lastKnown = result;
        _controller.add(result);
      },
      onError: _controller.addError,
      cancelOnError: false,
    );
  }

  Future<void> stopTracking() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Membuka pengaturan aplikasi — dipakai saat izin ditolak permanen.
  Future<bool> openSettings() => Geolocator.openAppSettings();

  Future<void> dispose() async {
    await stopTracking();
    await _controller.close();
  }

  // ── Perhitungan geografis ─────────────────────────────────────
  // Rumus di bawah menyalin `backend/src/common/utils/geo.ts` dengan sengaja.
  // Aplikasi memakainya hanya untuk umpan balik langsung — jarak pada radar dan
  // indikator "sudah dekat" — sementara keputusan yang mengikat tetap diambil
  // server. Menjaga keduanya identik membuat layar tidak pernah menjanjikan
  // sesuatu yang kemudian ditolak backend.

  static const double _earthRadiusM = 6371008.8;

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Jarak great-circle antara dua koordinat, dalam meter (Haversine).
  static double distanceMeters({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) {
    final dLat = _toRadians(toLat - fromLat);
    final dLon = _toRadians(toLon - fromLon);
    final lat1 = _toRadians(fromLat);
    final lat2 = _toRadians(toLat);

    final a = math.pow(math.sin(dLat / 2), 2) +
        math.pow(math.sin(dLon / 2), 2) * math.cos(lat1) * math.cos(lat2);

    return 2 * _earthRadiusM * math.asin(math.min(1, math.sqrt(a)));
  }

  /// Arah kompas dari satu titik ke titik lain, 0° = utara. Dipakai radar.
  static double bearingDegrees({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) {
    final lat1 = _toRadians(fromLat);
    final lat2 = _toRadians(toLat);
    final dLon = _toRadians(toLon - fromLon);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
