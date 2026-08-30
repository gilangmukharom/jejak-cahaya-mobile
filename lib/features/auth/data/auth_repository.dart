import '../../../core/constants/api_endpoints.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/models/json_utils.dart';
import '../../../core/models/user.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

/// Autentikasi dan siklus hidup sesi.
///
/// Repository ini pemegang tunggal urusan penyimpanan token: memanggil
/// [login]/[register] otomatis menyimpan sesi, dan [logout] membersihkannya —
/// sehingga tidak ada jalur yang bisa lupa melakukan salah satunya.
class AuthRepository {
  const AuthRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  })  : _api = apiClient,
        _tokenStorage = tokenStorage;

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  Future<AuthSession> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
  }) =>
      FailureMapper.guard(() async {
        final session = await _api.post(
          ApiEndpoints.register,
          body: {
            'email': email,
            'username': username,
            'password': password,
            'fullName': fullName,
          },
          parser: (data) => AuthSession.fromJson(Json.map(data)),
        );

        await _persist(session);
        return session;
      });

  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) =>
      FailureMapper.guard(() async {
        final session = await _api.post(
          ApiEndpoints.login,
          body: {'identifier': identifier, 'password': password},
          parser: (data) => AuthSession.fromJson(Json.map(data)),
        );

        await _persist(session);
        return session;
      });

  /// Mengambil profil pemain yang sedang login — dipakai saat aplikasi dibuka
  /// untuk memastikan sesi tersimpan masih sah.
  Future<User> fetchCurrentUser() => FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.me,
          parser: (data) => User.fromJson(Json.map(data)),
        ),
      );

  Future<User> updateProfile({String? fullName, String? avatarUrl}) =>
      FailureMapper.guard(
        () => _api.patch(
          ApiEndpoints.me,
          body: {
            if (fullName != null) 'fullName': fullName,
            if (avatarUrl != null) 'avatarUrl': avatarUrl,
          },
          parser: (data) => User.fromJson(Json.map(data)),
        ),
      );

  Future<PlayerStats> fetchStats() => FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.myStats,
          parser: (data) => PlayerStats.fromJson(Json.map(data)),
        ),
      );

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      FailureMapper.guard(() async {
        await _api.post<void>(
          ApiEndpoints.changePassword,
          body: {
            'currentPassword': currentPassword,
            'newPassword': newPassword
          },
          parser: (_) {},
        );

        // Backend mencabut seluruh sesi setelah kata sandi diganti, jadi token
        // yang tersimpan sudah tidak berlaku dan harus ikut dibuang.
        await _tokenStorage.clear();
      });

  /// Keluar. Panggilan ke server dilakukan sebaik mungkin: token lokal tetap
  /// dihapus meski permintaan gagal, agar pengguna tidak terjebak di sesi yang
  /// sudah mereka putuskan untuk ditinggalkan.
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefreshToken();

    if (refreshToken != null) {
      try {
        await _api.post<void>(
          ApiEndpoints.logout,
          body: {'refreshToken': refreshToken},
          parser: (_) {},
        );
      } on Object {
        // Diabaikan dengan sengaja — lihat catatan di atas.
      }
    }

    await _tokenStorage.clear();
  }

  Future<bool> hasStoredSession() => _tokenStorage.hasSession;

  Future<void> _persist(AuthSession session) => _tokenStorage.saveTokens(
        accessToken: session.tokens.accessToken,
        refreshToken: session.tokens.refreshToken,
      );
}
