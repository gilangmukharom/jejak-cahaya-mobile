/// Exception yang dilempar lapisan data sebelum diterjemahkan menjadi `Failure`
/// oleh repository.
class ServerException implements Exception {
  const ServerException({
    required this.message,
    this.code,
    this.statusCode,
    this.details,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, dynamic>? details;

  @override
  String toString() => 'ServerException($statusCode, $code): $message';
}

class NetworkException implements Exception {
  const NetworkException([this.message = 'Tidak ada koneksi internet']);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

class CacheException implements Exception {
  const CacheException([this.message = 'Gagal membaca data tersimpan']);

  final String message;

  @override
  String toString() => 'CacheException: $message';
}

/// Dilempar bila sesi tidak dapat dipulihkan; interceptor akan memaksa logout.
class UnauthorizedException implements Exception {
  const UnauthorizedException([this.message = 'Sesi Anda telah berakhir']);

  final String message;

  @override
  String toString() => 'UnauthorizedException: $message';
}
