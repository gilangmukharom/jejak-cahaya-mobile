import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/game/data/game_repository.dart';
import '../../features/game/presentation/cubit/geofence_cubit.dart';
import '../network/api_client.dart';
import '../network/dio_client.dart';
import '../services/basemap_service.dart';
import '../services/location_service.dart';
import '../services/prayer_notification_service.dart';
import '../services/scan_result_holder.dart';
import '../storage/app_preferences.dart';
import '../storage/token_storage.dart';

final GetIt sl = GetIt.instance;

/// Merakit grafik dependensi aplikasi.
///
/// Pendaftaran ditulis manual, bukan dibangkitkan `injectable`: seluruh grafik
/// muat dalam satu berkas yang bisa dibaca sekali lihat, dan proyek tidak
/// memerlukan langkah codegen apa pun untuk bisa dijalankan.
///
/// Aturan pembagiannya:
///  • `registerSingleton`     — layanan berumur sepanjang aplikasi (storage, jaringan).
///  • `registerLazySingleton` — dibuat saat pertama dipakai; repository tanpa state.
///  • `registerFactory`       — cubit berumur pendek, satu instance per layar.
///
/// [AuthCubit] dan [GeofenceCubit] menjadi pengecualian. Yang pertama disimpan
/// sebagai singleton karena router mengamatinya untuk menentukan pengalihan
/// halaman, dan seluruh aplikasi harus melihat status sesi yang sama persis.
/// Yang kedua karena tiga layar bergantung pada jawabannya sekaligus — gerbang,
/// peta, dan pemindai — dan membuat satu instance per layar berarti tiga
/// langganan GPS berjalan berbarengan serta tiga jawaban yang bisa berbeda.
Future<void> configureDependencies() async {
  // ── Penyimpanan ───────────────────────────────────────────────
  final preferences = await SharedPreferences.getInstance();

  sl
    ..registerSingleton<SharedPreferences>(preferences)
    ..registerSingleton<AppPreferences>(AppPreferences(preferences))
    ..registerSingleton<FlutterSecureStorage>(
      const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      ),
    )
    ..registerSingleton<TokenStorage>(TokenStorage(sl<FlutterSecureStorage>()));

  // ── Layanan perangkat ─────────────────────────────────────────
  sl
    ..registerSingleton<LocationService>(LocationService())
    ..registerSingleton<ScanResultHolder>(ScanResultHolder())
    // Jadwal sholat dihitung di perangkat; yang perlu dipegang lama hanyalah
    // penjadwal alarmnya, yang menyiapkan basis data zona waktu dan saluran
    // notifikasi sekali saja.
    ..registerSingleton<PrayerNotificationService>(
      PrayerNotificationService(sl<AppPreferences>()),
    )
    // Singleton karena arsip petanya hanya perlu disalin dan dibuka sekali:
    // membuatnya per layar berarti menyalin ulang 5 MB setiap kali pemain
    // berpindah tab lalu kembali ke peta.
    ..registerSingleton<BasemapService>(BasemapService());

  // ── Jaringan ──────────────────────────────────────────────────
  // Interceptor perlu memberi tahu AuthCubit saat sesi berakhir, sementara
  // AuthCubit sendiri bergantung pada jaringan. Lingkaran itu diputus lewat
  // callback yang baru menyentuh AuthCubit ketika benar-benar dipanggil —
  // pada saat itu seluruh pendaftaran sudah selesai.
  sl.registerSingleton<DioClient>(
    DioClient(
      tokenStorage: sl<TokenStorage>(),
      onSessionExpired: () async {
        if (sl.isRegistered<AuthCubit>()) {
          sl<AuthCubit>().onSessionExpired();
        }
      },
    ),
  );

  sl.registerSingleton<ApiClient>(ApiClient(sl<DioClient>().dio));

  // ── Repository ────────────────────────────────────────────────
  sl
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepository(
        apiClient: sl<ApiClient>(),
        tokenStorage: sl<TokenStorage>(),
      ),
    )
    ..registerLazySingleton<GameRepository>(
        () => GameRepository(sl<ApiClient>()));

  // ── State global ──────────────────────────────────────────────
  sl
    ..registerSingleton<AuthCubit>(AuthCubit(sl<AuthRepository>()))
    ..registerSingleton<GeofenceCubit>(
      GeofenceCubit(
        repository: sl<GameRepository>(),
        locationService: sl<LocationService>(),
        preferences: sl<AppPreferences>(),
      ),
    );
}

/// Membersihkan seluruh pendaftaran — dipakai pada pengujian.
Future<void> resetDependencies() async {
  await sl.reset();
}
