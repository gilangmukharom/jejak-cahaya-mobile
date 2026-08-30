import 'package:dio/dio.dart';

import '../error/exceptions.dart';
import 'api_response.dart';

/// Pembungkus tipis di atas Dio yang membongkar amplop response backend dan
/// menerjemahkan kegagalan menjadi exception aplikasi.
///
/// Semua data source memanggil kelas ini alih-alih Dio secara langsung, sehingga
/// bentuk `{ success, message, data }` hanya dipahami di satu tempat.
class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(Object? data) parser,
  }) =>
      _send(
        () => _dio.get<Map<String, dynamic>>(path,
            queryParameters: queryParameters),
        parser,
      );

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    required T Function(Object? data) parser,
  }) =>
      _send(
        () => _dio.post<Map<String, dynamic>>(
          path,
          data: body,
          queryParameters: queryParameters,
        ),
        parser,
      );

  Future<T> patch<T>(
    String path, {
    Object? body,
    required T Function(Object? data) parser,
  }) =>
      _send(() => _dio.patch<Map<String, dynamic>>(path, data: body), parser);

  /// Varian GET yang juga membawa metadata paginasi.
  Future<Paginated<T>> getPaginated<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(Map<String, dynamic> json) itemParser,
  }) async {
    final envelope = await _sendRaw(
      () => _dio.get<Map<String, dynamic>>(path,
          queryParameters: queryParameters),
    );

    final list = envelope['data'];
    final items = list is List
        ? list
            .whereType<Map<String, dynamic>>()
            .map(itemParser)
            .toList(growable: false)
        : <T>[];

    final meta = envelope['meta'];

    return Paginated<T>(
      items: items,
      meta: meta is Map<String, dynamic> ? PaginationMeta.fromJson(meta) : null,
    );
  }

  Future<T> _send<T>(
    Future<Response<Map<String, dynamic>>> Function() request,
    T Function(Object? data) parser,
  ) async {
    final envelope = await _sendRaw(request);
    return parser(envelope['data']);
  }

  Future<Map<String, dynamic>> _sendRaw(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final response = await request();
      final body = response.data;
      final status = response.statusCode ?? 0;

      if (body == null) {
        throw ServerException(
          message: 'Server mengirim response kosong',
          statusCode: status,
        );
      }

      if (status >= 400 || body['success'] != true) {
        final error = body['error'];
        throw ServerException(
          message: body['message'] as String? ?? 'Permintaan gagal',
          code: error is Map ? error['code'] as String? : null,
          statusCode: status,
          details:
              error is Map ? error['details'] as Map<String, dynamic>? : null,
        );
      }

      return body;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Exception _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(
          'Server tidak merespons. Periksa koneksi Anda lalu coba lagi.',
        );
      case DioExceptionType.connectionError:
        return const NetworkException(
          'Tidak dapat terhubung ke server. Pastikan Anda terhubung ke internet.',
        );
      case DioExceptionType.cancel:
        return const NetworkException('Permintaan dibatalkan');
      case DioExceptionType.badCertificate:
        return const NetworkException('Sertifikat server tidak valid');
      // Sisanya (badResponse, unknown, dan jenis baru yang mungkin ditambahkan
      // Dio di versi mendatang) diperlakukan sebagai kegagalan server.
      // validateStatus meloloskan status < 500, jadi yang sampai ke sini
      // umumnya kegagalan 5xx atau body yang tidak bisa diurai.
      default:
        final body = error.response?.data;
        return ServerException(
          message: body is Map
              ? (body['message'] as String? ?? 'Terjadi kesalahan pada server')
              : 'Terjadi kesalahan pada server',
          statusCode: error.response?.statusCode,
        );
    }
  }
}
