import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/user.dart';
import '../../data/auth_repository.dart';

enum AuthStatus { initial, checking, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.failure,
    this.isSubmitting = false,
  });

  final AuthStatus status;
  final User? user;
  final Failure? failure;

  /// True selama permintaan masuk/daftar berjalan — dipakai tombol untuk
  /// menampilkan indikator dan mencegah pengiriman ganda.
  final bool isSubmitting;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    Failure? failure,
    bool? isSubmitting,
    bool clearFailure = false,
    bool clearUser = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: clearUser ? null : (user ?? this.user),
        failure: clearFailure ? null : (failure ?? this.failure),
        isSubmitting: isSubmitting ?? this.isSubmitting,
      );

  @override
  List<Object?> get props => [status, user, failure, isSubmitting];
}

/// Sumber kebenaran tunggal untuk sesi pemain.
///
/// Router mengamati cubit ini untuk memutuskan apakah pengguna diarahkan ke
/// layar masuk atau ke permainan, sehingga tidak ada layar yang perlu memeriksa
/// status autentikasi sendiri.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthState());

  final AuthRepository _repository;

  /// Memulihkan sesi saat aplikasi dibuka.
  ///
  /// Keberadaan token tersimpan saja tidak cukup — token bisa saja sudah
  /// dicabut dari perangkat lain. Karena itu profil pemain benar-benar diambil
  /// untuk membuktikan sesi masih sah.
  Future<void> restoreSession() async {
    emit(state.copyWith(status: AuthStatus.checking, clearFailure: true));

    if (!await _repository.hasStoredSession()) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }

    try {
      final user = await _repository.fetchCurrentUser();
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Object catch (error) {
      final failure = FailureMapper.map(error);

      // Gangguan jaringan bukan berarti sesinya tidak sah. Memaksa logout di
      // sini akan mengeluarkan pemain hanya karena sinyal buruk — kondisi yang
      // justru sering terjadi di area masjid dengan tembok tebal.
      if (failure is NetworkFailure) {
        emit(
          state.copyWith(
            status: AuthStatus.unauthenticated,
            failure: failure,
          ),
        );
        return;
      }

      await _repository.logout();
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> login({required String identifier, required String password}) =>
      _submit(
          () => _repository.login(identifier: identifier, password: password));

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
  }) =>
      _submit(
        () => _repository.register(
          email: email,
          username: username,
          password: password,
          fullName: fullName,
        ),
      );

  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  /// Dipanggil interceptor ketika sesi tidak dapat diperbarui lagi.
  void onSessionExpired() {
    emit(
      const AuthState(
        status: AuthStatus.unauthenticated,
        failure: AuthFailure(
            message: 'Sesi Anda telah berakhir. Silakan masuk kembali.'),
      ),
    );
  }

  /// Menyegarkan profil setelah XP bertambah, agar kartu profil tidak basi.
  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;

    try {
      final user = await _repository.fetchCurrentUser();
      emit(state.copyWith(user: user));
    } on Object {
      // Kegagalan penyegaran tidak boleh mengganggu apa pun yang sedang
      // dikerjakan pemain; data lama tetap ditampilkan.
    }
  }

  void clearError() => emit(state.copyWith(clearFailure: true));

  Future<void> _submit(Future<AuthSession> Function() action) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    try {
      final session = await action();
      emit(AuthState(status: AuthStatus.authenticated, user: session.user));
    } on Object catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          failure: FailureMapper.map(error),
          isSubmitting: false,
        ),
      );
    }
  }
}
