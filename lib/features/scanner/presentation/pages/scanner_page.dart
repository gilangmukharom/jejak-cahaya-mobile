import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/scan_result_holder.dart';
import '../../../game/data/game_repository.dart';
import '../cubit/scanner_cubit.dart';

/// Layar pemindai QR.
///
/// Ini satu-satunya jalan memperoleh penemuan, jadi umpan baliknya dibuat
/// sejelas mungkin: setiap penolakan menjelaskan apa yang terjadi dan apa
/// langkah berikutnya, karena pemain sedang berdiri di lapangan.
class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ScannerCubit>(
      create: (_) => ScannerCubit(
        repository: sl<GameRepository>(),
        locationService: sl<LocationService>(),
      ),
      child: const _ScannerView(),
    );
  }
}

class _ScannerView extends StatefulWidget {
  const _ScannerView();

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  /// Mencoba membuka kamera lagi setelah gagal.
  ///
  /// Dipakai tombol pada layar galat. Jalur ini penting untuk kasus izin baru
  /// diberikan: percobaan pertama sudah terlanjur gagal, dan tanpa cara mencoba
  /// ulang satu-satunya jalan keluar adalah menutup aplikasi.
  Future<void> _retry() async {
    try {
      // Dihentikan lebih dulu, bukan langsung dinyalakan. `start()` memilih
      // keluar diam-diam ketika galat terakhirnya adalah izin ditolak, dan
      // galat itu baru dibersihkan oleh `stop()`. Tanpa langkah ini tombol
      // coba-lagi tidak melakukan apa pun justru pada kasus yang paling
      // membutuhkannya.
      await _controller.stop();
    } on Object {
      // Menghentikan kamera yang memang belum menyala bukan kegagalan.
    }

    try {
      await _controller.start();
    } on Object {
      // Kegagalan berulang tetap tergambar oleh errorBuilder.
    }
  }

  void _onDetect(BarcodeCapture capture) {
    // Penjagaan dibaca di sini, bukan dengan menukar callback saat build.
    // `MobileScanner` menangkap `onDetect` sekali saja di initState dan tidak
    // punya `didUpdateWidget`, jadi callback yang ditukar belakangan tidak
    // pernah benar-benar terpasang.
    if (context.read<ScannerCubit>().state.isBusy) return;

    final payload = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;

    if (payload == null || payload.isEmpty) return;

    context.read<ScannerCubit>().onQrDetected(payload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<ScannerCubit, ScannerState>(
        listenWhen: (previous, current) =>
            previous.stage != current.stage &&
            current.stage == ScannerStage.success,
        listener: (context, state) {
          final result = state.result;
          if (result == null) return;

          // Disimpan lebih dulu: halaman penemuan membacanya dari holder, bukan
          // dari `extra` milik router yang bisa hilang saat router menyegarkan
          // diri. Penyegaran profil dipicu di halaman penemuan, bukan di sini,
          // supaya emisi state-nya tidak berbenturan dengan navigasi ini.
          sl<ScanResultHolder>().save(result);
          context.pushReplacement(AppRoutes.discoveryResult);
        },
        builder: (context, state) {
          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                // Bingkai bidik dan tombol senter dititipkan ke overlayBuilder
                // supaya keduanya hanya tergambar ketika kamera benar-benar
                // hidup. Sebelumnya keduanya ditumpuk begitu saja di atas
                // MobileScanner, sehingga ketika kamera gagal dibuka layar
                // galatnya tertimbun bingkai kuning dan tulisan SCAN DI SINI —
                // menyuruh pemain mengarahkan kamera yang justru tidak menyala.
                overlayBuilder: (context, constraints) => Stack(
                  fit: StackFit.expand,
                  children: [
                    const _ScannerOverlay(),
                    _TorchButton(controller: _controller),
                  ],
                ),
                errorBuilder: (context, error) =>
                    _CameraErrorView(error: error, onRetry: _retry),
              ),
              // Tombol tutup berada di luar overlay: pemain harus selalu bisa
              // keluar, termasuk ketika kamera gagal atau masih menyiapkan diri.
              const _CloseButton(),
              if (state.stage == ScannerStage.validating)
                const _ValidatingOverlay(),
              if (state.stage == ScannerStage.rejected && state.failure != null)
                _RejectionSheet(state: state),
            ],
          );
        },
      ),
    );
  }
}

/// Bingkai bidik dengan lubang transparan di tengah.
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth * 0.68;

        return Stack(
          alignment: Alignment.center,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.6),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.gold, width: 2.5),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            Positioned(
              bottom: constraints.maxHeight * 0.5 - size / 2 - 72,
              child: Column(
                children: [
                  Text(
                    'SCAN DI SINI',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Arahkan kamera ke QR Code di checkpoint',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Tutup',
          ),
        ),
      ),
    );
  }
}

/// Tombol senter yang mengikuti keadaan kamera sesungguhnya.
///
/// Sebelumnya ikonnya tetap dan tombolnya selalu bisa ditekan, sehingga pemain
/// menekannya berulang kali tanpa tahu apakah ada yang terjadi — dan ketika
/// kamera memang belum menyala, atau perangkatnya tidak punya senter, memang
/// tidak akan pernah terjadi apa-apa.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (context, state, child) {
              final unavailable = state.torchState == TorchState.unavailable;
              final isOn = state.torchState == TorchState.on;

              return IconButton(
                onPressed: unavailable ? null : controller.toggleTorch,
                icon: Icon(
                  isOn
                      ? Icons.flashlight_on_rounded
                      : Icons.flashlight_off_rounded,
                  color: unavailable
                      ? Colors.white24
                      : isOn
                          ? AppColors.gold
                          : Colors.white,
                ),
                tooltip: unavailable
                    ? 'Senter tidak tersedia di perangkat ini'
                    : isOn
                        ? 'Matikan senter'
                        : 'Nyalakan senter',
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ValidatingOverlay extends StatelessWidget {
  const _ValidatingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Memverifikasi lokasi…',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Memeriksa geofence, jarak checkpoint, dan keaslian QR',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lembar penolakan: alasan dari server ditambah petunjuk langkah berikutnya.
class _RejectionSheet extends StatelessWidget {
  const _RejectionSheet({required this.state});

  final ScannerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failure = state.failure!;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.gpp_maybe_rounded,
                  color: AppColors.danger,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                failure.message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                ScannerCubit.hintFor(failure),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Kembali'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.read<ScannerCubit>().resume(),
                      child: const Text('Pindai Lagi'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ditampilkan ketika kamera gagal dibuka.
///
/// Sebelumnya layar ini hanya menyediakan tombol "Kembali", sehingga setiap
/// kegagalan menjadi jalan buntu — termasuk kegagalan yang penyebabnya sudah
/// hilang, seperti izin yang baru saja diberikan. Sekarang jalan keluarnya
/// selalu ada: mencoba lagi tanpa meninggalkan layar, dan membuka pengaturan
/// bila memang izinnya yang perlu diubah.
class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.error, required this.onRetry});

  final MobileScannerException error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isPermissionProblem =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Izin kamera ditolak. Aktifkan akses kamera di pengaturan aplikasi untuk memindai QR.',
      MobileScannerErrorCode.unsupported =>
        'Perangkat ini tidak mendukung pemindaian QR.',
      _ =>
        'Kamera tidak dapat dibuka. Coba tutup aplikasi lain yang sedang memakainya.',
    };

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_rounded,
                size: 56,
                color: Colors.white54,
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              if (isPermissionProblem)
                FilledButton.icon(
                  // `LocationService.openSettings` membuka halaman rincian
                  // aplikasi di pengaturan sistem — tempat SELURUH izin diatur,
                  // termasuk kamera. Namanya memang menyebut lokasi karena di
                  // situlah ia pertama dibutuhkan; memakainya di sini lebih
                  // ringan daripada menambah paket izin baru hanya untuk satu
                  // tombol.
                  onPressed: () => sl<LocationService>().openSettings(),
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Buka Pengaturan'),
                )
              else
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba lagi'),
                ),
              const SizedBox(height: 10),
              if (isPermissionProblem)
                // Setelah izin diubah di pengaturan, kamera perlu dinyalakan
                // ulang dari sini — kembali ke halaman ini saja tidak cukup
                // karena percobaan pertamanya sudah terlanjur gagal.
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(foregroundColor: AppColors.gold),
                  child: const Text('Sudah diizinkan — coba lagi'),
                ),
              OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  side: const BorderSide(color: AppColors.gold),
                ),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
