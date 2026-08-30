/// Konfigurasi aplikasi yang berasal dari `--dart-define` saat kompilasi.
///
/// Dipakai lewat `--dart-define` alih-alih berkas `.env` karena nilainya
/// tertanam saat build: tidak ada berkas konfigurasi yang bisa tertukar antar
/// lingkungan, dan build produksi tidak mungkin diam-diam menunjuk API lokal.
class AppConfig {
  const AppConfig._();

  /// Alamat basis API.
  ///
  /// Nilai bawaan `10.0.2.2` adalah alamat host dari Android Emulator.
  /// Untuk perangkat fisik, gunakan IP LAN komputer Anda:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api/v1
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  static const String appName = 'Jejak Cahaya';
  static const String appTagline = 'Jelajahi. Temukan. Pelajari. Warisi.';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Jarak minimal (meter) sebelum pembaruan lokasi baru dipancarkan.
  ///
  /// Nilai kecil membuat radar terasa responsif; nilai terlalu kecil membuat
  /// GPS bekerja terus-menerus dan menguras baterai saat pemain berdiri diam.
  static const int locationDistanceFilterM = 3;

  /// Akurasi GPS terburuk yang masih dianggap layak untuk memindai.
  /// Harus sejalan dengan `MAX_GPS_ACCURACY_M` di backend.
  static const double maxGpsAccuracyM = 75;

  static const bool enableNetworkLogging = bool.fromEnvironment(
    'ENABLE_NETWORK_LOG',
    defaultValue: true,
  );
}
