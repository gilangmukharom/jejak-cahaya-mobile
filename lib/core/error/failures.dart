import 'package:equatable/equatable.dart';

/// Kode error yang dikirim backend. Nilainya harus sama persis dengan
/// `ErrorCode` di `backend/src/common/errors/AppError.ts`.
class ApiErrorCode {
  const ApiErrorCode._();

  static const String validationError = 'VALIDATION_ERROR';
  static const String notFound = 'NOT_FOUND';
  static const String conflict = 'CONFLICT';
  static const String rateLimited = 'RATE_LIMITED';

  static const String unauthorized = 'UNAUTHORIZED';
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String tokenExpired = 'TOKEN_EXPIRED';
  static const String tokenInvalid = 'TOKEN_INVALID';
  static const String emailTaken = 'EMAIL_TAKEN';
  static const String usernameTaken = 'USERNAME_TAKEN';

  static const String qrInvalid = 'QR_INVALID';
  static const String qrSignatureInvalid = 'QR_SIGNATURE_INVALID';
  static const String outsideGeofence = 'OUTSIDE_GEOFENCE';
  static const String tooFarFromCheckpoint = 'TOO_FAR_FROM_CHECKPOINT';
  static const String poorGpsAccuracy = 'POOR_GPS_ACCURACY';
  static const String mockLocationDetected = 'MOCK_LOCATION_DETECTED';
  static const String alreadyDiscovered = 'ALREADY_DISCOVERED';

  static const String missionLocked = 'MISSION_LOCKED';
  static const String quizLocked = 'QUIZ_LOCKED';
  static const String quizAttemptLimit = 'QUIZ_ATTEMPT_LIMIT';
}

/// Kegagalan yang sudah diterjemahkan menjadi bentuk yang siap ditampilkan.
///
/// Lapisan presentasi tidak pernah menyentuh `DioException` atau kode status
/// HTTP — semuanya sudah menjadi [Failure] dengan pesan berbahasa Indonesia.
///
/// Mengimplementasikan `Exception` karena repository melemparnya sebagai alur
/// kegagalan; tanpa itu ia menjadi objek lempar yang tidak lazim di Dart.
sealed class Failure extends Equatable implements Exception {
  const Failure({required this.message, this.code, this.details});

  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  @override
  List<Object?> get props => [message, code, details];
}

/// Kesalahan dari server dengan bentuk error yang terstruktur.
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.code,
    super.details,
    this.statusCode,
  });

  final int? statusCode;

  @override
  List<Object?> get props => [...super.props, statusCode];
}

/// Tidak ada koneksi, atau permintaan melewati batas waktu.
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message =
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
    super.code,
  });
}

/// Sesi berakhir dan tidak dapat diperbarui — pengguna harus masuk kembali.
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

/// Kegagalan terkait izin atau layanan lokasi perangkat.
class LocationFailure extends Failure {
  const LocationFailure(
      {required super.message, this.isPermanentlyDenied = false});

  /// True bila pengguna memilih "jangan tanya lagi" — satu-satunya jalan keluar
  /// adalah membuka pengaturan sistem, bukan meminta izin ulang.
  final bool isPermanentlyDenied;

  @override
  List<Object?> get props => [...super.props, isPermanentlyDenied];
}

/// Kesalahan tak terduga yang tidak masuk kategori mana pun.
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'Terjadi kesalahan yang tidak diketahui.',
    super.code,
  });
}
