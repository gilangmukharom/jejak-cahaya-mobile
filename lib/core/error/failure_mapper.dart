import 'exceptions.dart';
import 'failures.dart';

/// Menerjemahkan exception lapisan data menjadi [Failure] yang siap ditampilkan.
///
/// Repository memanggil [guard] agar lapisan presentasi hanya pernah berhadapan
/// dengan [Failure] — tidak pernah dengan `DioException`, kode status HTTP, atau
/// exception platform.
class FailureMapper {
  const FailureMapper._();

  static Failure map(Object error) {
    if (error is Failure) return error;

    if (error is ServerException) {
      final code = error.code;

      // 401 yang bukan sekadar kredensial salah berarti sesi memang berakhir;
      // pemanggil perlu membedakannya agar bisa memaksa kembali ke layar masuk.
      if (error.statusCode == 401 && code != ApiErrorCode.invalidCredentials) {
        return AuthFailure(message: error.message, code: code);
      }

      return ServerFailure(
        message: error.message,
        code: code,
        details: error.details,
        statusCode: error.statusCode,
      );
    }

    if (error is NetworkException) {
      return NetworkFailure(message: error.message);
    }

    if (error is UnauthorizedException) {
      return AuthFailure(
          message: error.message, code: ApiErrorCode.tokenInvalid);
    }

    if (error is CacheException) {
      return UnknownFailure(message: error.message);
    }

    return const UnknownFailure();
  }

  /// Menjalankan [action] dan memetakan kegagalannya menjadi [Failure].
  static Future<T> guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      throw map(error);
    }
  }
}
