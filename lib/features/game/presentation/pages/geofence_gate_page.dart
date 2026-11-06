import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/widgets/supported_by_pik2.dart';
import '../cubit/geofence_cubit.dart';

/// Layar pembuka: mencari sinyal GPS, lalu meneruskan pemain ke aplikasi.
///
/// Dulu layar ini adalah gerbang dalam arti sesungguhnya — ia menahan siapa pun
/// yang berada di luar radius masjid dan tidak melepasnya sampai mereka datang.
/// Sekarang tidak lagi. Berada di luar area hanya berarti peta dan pemindai
/// tertutup; jadwal sholat, arah kiblat, koleksi, misi, dan profil tetap bisa
/// dibuka, dan kabar "Anda di luar area" disampaikan di tab Peta, di tempat
/// yang memang menjelaskan apa yang sedang terkunci.
///
/// Yang tersisa di sini hanyalah dua pekerjaan yang memang harus terjadi lebih
/// dulu: meminta izin lokasi, dan menunggu bacaan GPS pertama. Keduanya pun
/// bisa dilewati — tombol di layar izin membiarkan pemain masuk tanpa lokasi.
class GeofenceGatePage extends StatefulWidget {
  const GeofenceGatePage({super.key});

  @override
  State<GeofenceGatePage> createState() => _GeofenceGatePageState();
}

class _GeofenceGatePageState extends State<GeofenceGatePage> {
  late final GeofenceCubit _cubit = sl<GeofenceCubit>();

  @override
  void initState() {
    super.initState();

    // Cubit-nya berumur sepanjang aplikasi, jadi pemeriksaan hanya dimulai
    // ketika memang belum pernah berjalan — pemain yang kembali ke gerbang
    // setelah keluar-masuk akun tidak perlu menunggu GPS dari nol lagi.
    if (_cubit.state.stage == GeofenceStage.initial) {
      _cubit.initialize();
      return;
    }

    // Jawabannya sudah ada dari sesi sebelumnya. Pendengar di bawah hanya
    // menyala pada *perubahan* menjadi terjawab, jadi tanpa langkah ini layar
    // akan berhenti selamanya pada pemutar tunggu — persis pada pemain yang
    // baru saja masuk kembali ke akunnya.
    if (_cubit.state.isResolved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.explore);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GeofenceCubit>.value(
      value: _cubit,
      child: const _GeofenceGateView(),
    );
  }
}

class _GeofenceGateView extends StatelessWidget {
  const _GeofenceGateView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: BlocConsumer<GeofenceCubit, GeofenceState>(
            listenWhen: (previous, current) =>
                !previous.isResolved && current.isResolved,
            listener: (context, state) {
              // Terjawab — apa pun jawabannya. Pemain diteruskan ke peta, dan
              // peta sendiri yang memutuskan menampilkan permainan atau kartu
              // "di luar area".
              context.go(AppRoutes.explore);
            },
            builder: (context, state) => switch (state.stage) {
              GeofenceStage.initial ||
              GeofenceStage.locating =>
                const _LocatingView(),
              GeofenceStage.inside ||
              GeofenceStage.outside =>
                const _LocatingView(message: 'Membuka aplikasi…'),
              GeofenceStage.locationBlocked => _BlockedView(state: state),
              GeofenceStage.error => _ErrorView(state: state),
            },
          ),
        ),
      ),
    );
  }
}

/// Layar tunggu saat sinyal GPS dicari.
///
/// Kredit sponsor diletakkan di sini, bukan pada [LoadingView] umum: widget itu
/// dipakai di dalam halaman-halaman yang sudah punya bilah dan isinya sendiri,
/// sehingga logonya akan muncul berulang di tempat yang tidak masuk akal —
/// termasuk di halaman profil, yang sudah memuat kredit yang sama di footer.
/// Layar ini justru sebaliknya: satu layar penuh yang isinya hanya menunggu.
class _LocatingView extends StatelessWidget {
  const _LocatingView({this.message = 'Mencari sinyal GPS…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppColors.textOnDark),
              ),
              const SizedBox(height: 8),
              Text(
                'Pastikan Anda berada di area terbuka',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textOnDark.withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 26,
          child: Center(child: SupportedByPik2(onDark: true, logoWidth: 104)),
        ),
      ],
    );
  }
}

/// Izin lokasi ditolak atau GPS mati.
class _BlockedView extends StatelessWidget {
  const _BlockedView({required this.state});

  final GeofenceState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failure = state.failure;
    final isPermanent =
        failure is LocationFailure && failure.isPermanentlyDenied;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.location_disabled_rounded,
            size: 64,
            color: AppColors.gold,
          ),
          const SizedBox(height: 28),
          Text(
            'Izin Lokasi Diperlukan',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            failure?.message ??
                'Aplikasi membutuhkan akses lokasi untuk mendeteksi checkpoint di sekitar Anda.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textOnDark.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final cubit = context.read<GeofenceCubit>();
                // Bila izin ditolak permanen, meminta ulang tidak akan
                // memunculkan dialog apa pun — satu-satunya jalan adalah
                // pengaturan sistem.
                if (isPermanent) {
                  cubit.openLocationSettings();
                } else {
                  cubit.refresh();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.primaryDark,
              ),
              child: Text(
                isPermanent ? 'Buka Pengaturan' : 'Izinkan Akses Lokasi',
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Tanpa lokasi, yang hilang hanyalah permainannya. Jadwal sholat masih
          // bisa dihitung dari posisi tersimpan, dan sisa aplikasi tidak
          // memerlukan koordinat sama sekali — jadi menahan orang di layar ini
          // hanya akan menutup hal-hal yang sebetulnya siap dipakai.
          TextButton(
            onPressed: () => context.go(AppRoutes.explore),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textOnDark.withValues(alpha: 0.8),
            ),
            child: const Text('Lanjut tanpa lokasi'),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.state});

  final GeofenceState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.gold),
          const SizedBox(height: 28),
          Text(
            'Gagal Memuat',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            state.failure?.message ?? 'Terjadi kesalahan yang tidak diketahui.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textOnDark.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.read<GeofenceCubit>().initialize(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.primaryDark,
              ),
              child: const Text('Coba Lagi'),
            ),
          ),
          const SizedBox(height: 10),

          // Daftar masjid gagal dimuat bukan alasan menutup jadwal sholat, yang
          // dihitung sepenuhnya di perangkat dan tidak memerlukan server.
          TextButton(
            onPressed: () => context.go(AppRoutes.worship),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textOnDark.withValues(alpha: 0.8),
            ),
            child: const Text('Buka jadwal sholat'),
          ),
        ],
      ),
    );
  }
}
