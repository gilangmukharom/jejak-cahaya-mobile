import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../data/game_repository.dart';
import '../cubit/geofence_cubit.dart';

/// Gerbang masuk permainan — penegakan Layer 1 di sisi antarmuka.
///
/// Selama pemain berada di luar radius masjid, layar ini menahan mereka dan
/// menunjukkan berapa jauh lagi jarak yang harus ditempuh. Cubit terus memantau
/// posisi, jadi gerbang terbuka sendiri begitu pemain melangkah masuk — tanpa
/// perlu menutup dan membuka ulang aplikasi.
class GeofenceGatePage extends StatelessWidget {
  const GeofenceGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GeofenceCubit>(
      create: (_) => GeofenceCubit(
        repository: sl<GameRepository>(),
        locationService: sl<LocationService>(),
        preferences: sl<AppPreferences>(),
      )..initialize(),
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
                !previous.isUnlocked && current.isUnlocked,
            listener: (context, state) {
              // Begitu pemain masuk area, langsung teruskan ke peta.
              context.go(AppRoutes.explore);
            },
            builder: (context, state) => switch (state.stage) {
              GeofenceStage.initial ||
              GeofenceStage.locating =>
                const _LocatingView(),
              GeofenceStage.inside => const _LocatingView(
                  message: 'Membuka penjelajahan…',
                ),
              GeofenceStage.outside => _OutsideView(state: state),
              GeofenceStage.locationBlocked => _BlockedView(state: state),
              GeofenceStage.error => _ErrorView(state: state),
            },
          ),
        ),
      ),
    );
  }
}

class _LocatingView extends StatelessWidget {
  const _LocatingView({this.message = 'Mencari sinyal GPS…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}

/// Layar terkunci: pemain berada di luar radius masjid.
class _OutsideView extends StatelessWidget {
  const _OutsideView({required this.state});

  final GeofenceState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = state.status;
    final mosqueName = status?.mosque.name ?? 'masjid';
    final away = state.metersAway ?? 0;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 52,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Jejak Cahaya Terkunci',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Permainan hanya dapat dimainkan di dalam area $mosqueName.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textOnDark.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              children: [
                Text(
                  'Jarak Anda ke area masjid',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDistance(away),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Radius area: ${status?.radiusMeters ?? 250} m',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.read<GeofenceCubit>().refresh(),
              icon: const Icon(Icons.my_location_rounded, size: 20),
              label: const Text('Periksa Lokasi Saya'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: const BorderSide(color: AppColors.gold, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Lokasi diperiksa otomatis — layar akan terbuka\nsendiri saat Anda tiba di masjid.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textOnDark.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
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
        ],
      ),
    );
  }
}
