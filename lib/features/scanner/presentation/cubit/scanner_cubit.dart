import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/scan_result.dart';
import '../../../../core/services/location_service.dart';
import '../../../game/data/game_repository.dart';

enum ScannerStage {
  /// Kamera aktif, menunggu QR terbaca.
  scanning,

  /// QR terbaca, sedang divalidasi server.
  validating,

  /// Penemuan berhasil.
  success,

  /// Ditolak — lihat [ScannerState.failure] untuk alasannya.
  rejected,
}

class ScannerState extends Equatable {
  const ScannerState({
    this.stage = ScannerStage.scanning,
    this.result,
    this.failure,
    this.torchOn = false,
  });

  final ScannerStage stage;
  final ScanResult? result;
  final Failure? failure;
  final bool torchOn;

  /// Selama validasi berjalan, pemindai harus berhenti membaca agar satu QR
  /// tidak terkirim berkali-kali — kamera memancarkan puluhan frame per detik.
  bool get isBusy => stage == ScannerStage.validating;

  ScannerState copyWith({
    ScannerStage? stage,
    ScanResult? result,
    Failure? failure,
    bool? torchOn,
    bool clearFailure = false,
    bool clearResult = false,
  }) =>
      ScannerState(
        stage: stage ?? this.stage,
        result: clearResult ? null : (result ?? this.result),
        failure: clearFailure ? null : (failure ?? this.failure),
        torchOn: torchOn ?? this.torchOn,
      );

  @override
  List<Object?> get props => [stage, result, failure, torchOn];
}

/// Mengendalikan layar pemindai QR.
///
/// Alur satu kali pindai: baca QR → ambil posisi terkini → kirim ke server →
/// tampilkan penemuan atau alasan penolakan. Seluruh penilaian dilakukan
/// server; cubit ini tidak pernah memutuskan sendiri apakah sebuah scan sah.
class ScannerCubit extends Cubit<ScannerState> {
  ScannerCubit({
    required GameRepository repository,
    required LocationService locationService,
  })  : _repository = repository,
        _location = locationService,
        super(const ScannerState());

  final GameRepository _repository;
  final LocationService _location;

  /// Payload yang barusan diproses, agar QR yang sama tidak dikirim berulang
  /// hanya karena kamera terus menyorotnya.
  String? _lastPayload;

  Future<void> onQrDetected(String payload) async {
    if (state.isBusy) return;
    if (payload == _lastPayload && state.stage == ScannerStage.rejected) return;

    _lastPayload = payload;
    emit(state.copyWith(stage: ScannerStage.validating, clearFailure: true));

    try {
      // Posisi diambil segar, bukan dari cache: pemain baru saja berjalan
      // mendekat, dan pembacaan lama bisa menempatkannya di titik sebelumnya.
      final position = await _location.getCurrentPosition();

      if (!position.isAccurateEnough) {
        emit(
          state.copyWith(
            stage: ScannerStage.rejected,
            failure: LocationFailure(
              message:
                  'Sinyal GPS kurang akurat (±${position.accuracyM.round()} m). '
                  'Coba pindah ke area yang lebih terbuka lalu pindai ulang.',
            ),
          ),
        );
        return;
      }

      final result =
          await _repository.scan(payload: payload, position: position);

      emit(state.copyWith(
          stage: ScannerStage.success, result: result, clearFailure: true));
    } on Object catch (error) {
      emit(
        state.copyWith(
          stage: ScannerStage.rejected,
          failure: FailureMapper.map(error),
        ),
      );
    }
  }

  /// Kembali memindai setelah penolakan.
  void resume() {
    _lastPayload = null;
    emit(
      state.copyWith(
        stage: ScannerStage.scanning,
        clearFailure: true,
        clearResult: true,
      ),
    );
  }

  void toggleTorch() => emit(state.copyWith(torchOn: !state.torchOn));

  /// Pesan yang dapat ditindaklanjuti untuk setiap alasan penolakan.
  ///
  /// Pesan bawaan dari server sudah berbahasa Indonesia dan sudah spesifik;
  /// yang ditambahkan di sini adalah petunjuk langkah berikutnya, karena pemain
  /// sedang berdiri di lapangan dan butuh tahu harus berbuat apa.
  static String hintFor(Failure failure) => switch (failure.code) {
        ApiErrorCode.outsideGeofence =>
          'Datang ke area masjid untuk mulai menjelajah.',
        ApiErrorCode.tooFarFromCheckpoint =>
          'Berjalanlah mendekat ke titik checkpoint, lalu pindai lagi.',
        ApiErrorCode.qrSignatureInvalid ||
        ApiErrorCode.qrInvalid =>
          'Pastikan Anda memindai QR resmi Jejak Cahaya di lokasi checkpoint.',
        ApiErrorCode.mockLocationDetected =>
          'Nonaktifkan aplikasi lokasi palsu, lalu buka ulang Jejak Cahaya.',
        ApiErrorCode.poorGpsAccuracy =>
          'Keluar ke area terbuka agar sinyal GPS lebih kuat.',
        ApiErrorCode.alreadyDiscovered =>
          'Tokoh ini sudah ada di koleksi Anda. Cari checkpoint lain di peta.',
        ApiErrorCode.missionLocked =>
          'Selesaikan checkpoint sebelumnya terlebih dahulu.',
        ApiErrorCode.rateLimited => 'Tunggu sebentar sebelum memindai lagi.',
        _ => 'Coba pindai ulang. Bila terus gagal, hubungi pengurus masjid.',
      };
}
