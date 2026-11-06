import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan token autentikasi.
///
/// Memakai penyimpanan terenkripsi milik sistem (Keystore di Android, Keychain
/// di iOS), bukan SharedPreferences — refresh token berumur 30 hari, dan pada
/// perangkat yang di-root SharedPreferences dapat dibaca aplikasi lain.
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'jc_access_token';
  static const String _refreshTokenKey = 'jc_refresh_token';

  /// Cache di memori agar interceptor tidak perlu menyentuh Keystore pada setiap
  /// permintaan — pembacaan secure storage relatif lambat (beberapa milidetik).
  String? _cachedAccessToken;

  Future<String?> readAccessToken() async {
    return _cachedAccessToken ??= await _storage.read(key: _accessTokenKey);
  }

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<void> clear() async {
    _cachedAccessToken = null;
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  Future<bool> get hasSession async => (await readRefreshToken()) != null;
}
