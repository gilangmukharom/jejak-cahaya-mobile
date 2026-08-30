import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../constants/api_endpoints.dart';
import '../error/exceptions.dart';
import '../storage/token_storage.dart';

/// Dipanggil ketika sesi benar-benar tidak dapat dipulihkan, agar aplikasi
/// membersihkan state dan mengarahkan pengguna kembali ke layar masuk.
typedef OnSessionExpired = Future<void> Function();

/// Membangun instance [Dio] beserta seluruh interceptor-nya.
class DioClient {
  DioClient({
    required TokenStorage tokenStorage,
    required OnSessionExpired onSessionExpired,
  })  : _tokenStorage = tokenStorage,
        _onSessionExpired = onSessionExpired {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: Headers.jsonContentType,
        // Status < 500 tidak dianggap error transport; error bisnis dibaca dari
        // body agar `code` dan `details` dari backend tidak hilang.
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    _dio.interceptors.add(_authInterceptor());

    if (AppConfig.enableNetworkLogging) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          compact: true,
          maxWidth: 100,
        ),
      );
    }
  }

  final TokenStorage _tokenStorage;
  final OnSessionExpired _onSessionExpired;
  late final Dio _dio;

  Dio get dio => _dio;

  /// Menjaga agar beberapa permintaan yang bersamaan menerima 401 tidak
  /// memicu refresh berkali-kali. Backend merotasi refresh token setiap kali
  /// dipakai dan mencabut seluruh sesi bila token bekas dipakai ulang — dua
  /// refresh paralel akan membuat pengguna ter-logout paksa.
  Future<void>? _refreshInFlight;

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final isAuthCall = options.path.startsWith('/auth/');
        if (!isAuthCall) {
          final token = await _tokenStorage.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        final status = response.statusCode ?? 0;
        final body = response.data;

        final isExpiredToken = status == 401 &&
            body is Map &&
            (body['error'] as Map?)?['code'] == 'TOKEN_EXPIRED';

        // Refresh diam-diam lalu ulangi permintaan aslinya sekali.
        if (isExpiredToken &&
            !response.requestOptions.path.startsWith('/auth/')) {
          final refreshed = await _refreshSession();
          if (refreshed) {
            try {
              final retry = await _retry(response.requestOptions);
              handler.resolve(retry);
              return;
            } on DioException catch (error) {
              handler.reject(error);
              return;
            }
          }

          await _onSessionExpired();
        }

        handler.next(response);
      },
      onError: (error, handler) => handler.next(error),
    );
  }

  Future<bool> _refreshSession() async {
    // Satukan permintaan refresh yang bersamaan menjadi satu panggilan.
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      await inFlight;
      return (await _tokenStorage.readAccessToken()) != null;
    }

    final completer = _performRefresh();
    _refreshInFlight = completer;

    try {
      await completer;
      return true;
    } on Exception {
      return false;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<void> _performRefresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) {
      throw const UnauthorizedException();
    }

    // Instance Dio terpisah: memakai `_dio` akan melewati interceptor ini lagi
    // dan berpotensi memicu rekursi tak berujung saat refresh sendiri gagal.
    final plain = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
    final response = await plain.post<Map<String, dynamic>>(
      ApiEndpoints.refresh,
      data: {'refreshToken': refreshToken},
    );

    final tokens = (response.data?['data'] as Map?)?['tokens'];
    if (tokens is! Map) {
      throw const UnauthorizedException();
    }

    await _tokenStorage.saveTokens(
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
    );
  }

  Future<Response<dynamic>> _retry(RequestOptions options) {
    final token = _tokenStorage.readAccessToken();

    return token.then(
      (value) => _dio.fetch<dynamic>(
        options..headers['Authorization'] = 'Bearer $value',
      ),
    );
  }
}
