import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/checkpoint.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/scan_result_holder.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/game_repository.dart';
import '../cubit/explore_cubit.dart';
import '../widgets/checkpoint_detail_sheet.dart';
import '../widgets/checkpoint_radar.dart';

/// Layar utama permainan: peta area masjid, radar checkpoint terdekat,
/// dan ringkasan misi yang sedang berjalan.
class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final mosqueId = sl<AppPreferences>().lastMosqueId;

    return BlocProvider<ExploreCubit>(
      create: (_) {
        final cubit = ExploreCubit(
          repository: sl<GameRepository>(),
          locationService: sl<LocationService>(),
          scanResults: sl<ScanResultHolder>(),
        );
        if (mosqueId != null) cubit.load(mosqueId);
        return cubit;
      },
      child: _ExploreView(mosqueId: mosqueId),
    );
  }
}

class _ExploreView extends StatelessWidget {
  const _ExploreView({this.mosqueId});

  final String? mosqueId;

  @override
  Widget build(BuildContext context) {
    if (mosqueId == null) {
      return Scaffold(
        body: EmptyView(
          icon: Icons.mosque_outlined,
          title: 'Masjid belum dipilih',
          message: 'Kembali ke beranda untuk memilih lokasi penjelajahan.',
          action: FilledButton(
            onPressed: () => context.go(AppRoutes.gate),
            child: const Text('Pilih Masjid'),
          ),
        ),
      );
    }

    return Scaffold(
      body: BlocBuilder<ExploreCubit, ExploreState>(
        builder: (context, state) {
          if (state.isLoading && state.checkpoints.isEmpty) {
            return const LoadingView(message: 'Memuat checkpoint di sekitar…');
          }

          final failure = state.failure;
          if (failure != null && state.checkpoints.isEmpty) {
            return FailureView(
              failure: failure,
              onRetry: () => context.read<ExploreCubit>().load(mosqueId!),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<ExploreCubit>().load(mosqueId!),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _MapPanel(state: state)),
                SliverToBoxAdapter(child: _ProgressStrip(state: state)),
                if (state.nearestPending != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    sliver: SliverToBoxAdapter(
                      child: CheckpointRadar(
                        checkpoint: state.nearestPending!,
                        onTap: () => context.push(AppRoutes.scanner),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Checkpoint di Masjid',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SliverList.separated(
                    itemCount: state.checkpoints.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _CheckpointTile(
                      checkpoint: state.checkpoints[index],
                      onTap: () => CheckpointDetailSheet.show(
                        context,
                        state.checkpoints[index],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Peta OpenStreetMap dengan lingkaran geofence dan penanda checkpoint.
class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.state});

  final ExploreState state;

  @override
  Widget build(BuildContext context) {
    final position = state.position;
    final center = position != null
        ? LatLng(position.latitude, position.longitude)
        : state.checkpoints.isNotEmpty
            ? LatLng(
                state.checkpoints.first.latitude,
                state.checkpoints.first.longitude,
              )
            : const LatLng(-6.1094, 106.7395);

    // Seluruh titik yang harus muat di layar: checkpoint ditambah posisi pemain.
    final points = <LatLng>[
      for (final checkpoint in state.checkpoints)
        LatLng(checkpoint.latitude, checkpoint.longitude),
      if (position != null) LatLng(position.latitude, position.longitude),
    ];

    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 17,
              minZoom: 3,
              maxZoom: 19,
              // Zoom tetap membuat checkpoint gampang berada di luar layar —
              // pemain hanya melihat hamparan kosong dan mengira petanya rusak.
              // Bingkai kamera disesuaikan agar semua titik pasti terlihat.
              initialCameraFit: points.length > 1
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(points),
                      padding: const EdgeInsets.all(48),
                      maxZoom: 18,
                    )
                  : null,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                // OpenStreetMap mensyaratkan identifikasi aplikasi pada
                // permintaan tile; ganti dengan applicationId Anda saat rilis.
                userAgentPackageName: 'id.jejakcahaya.app',
                maxZoom: 19,
              ),
              // Radius checkpoint TIDAK lagi digambar sebagai lingkaran
              // berskala meter untuk semua titik. Radiusnya bisa mencapai
              // ratusan meter sementara peta sedekat ini hanya mencakup puluhan
              // meter — lingkarannya saling menimpa, menutupi seluruh jalan,
              // dan peta tampak seperti bidang hijau polos.
              //
              // Yang digambar hanya radius satu checkpoint terdekat yang belum
              // ditemukan, sebagai penunjuk seberapa dekat pemain harus berada.
              if (state.nearestPending != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(
                        state.nearestPending!.latitude,
                        state.nearestPending!.longitude,
                      ),
                      radius: state.nearestPending!.radiusMeters.toDouble(),
                      useRadiusInMeter: true,
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderColor: AppColors.gold.withValues(alpha: 0.7),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final checkpoint in state.checkpoints)
                    Marker(
                      point: LatLng(checkpoint.latitude, checkpoint.longitude),
                      width: 34,
                      height: 34,
                      child: _CheckpointPin(checkpoint: checkpoint),
                    ),
                  if (position != null)
                    Marker(
                      point: LatLng(position.latitude, position.longitude),
                      width: 22,
                      height: 22,
                      child: const _PlayerPin(),
                    ),
                ],
              ),
              // Atribusi wajib menurut ketentuan penggunaan OpenStreetMap.
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          if (state.failure != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _OfflineBanner(message: state.failure!.message),
            ),
        ],
      ),
    );
  }
}

class _CheckpointPin extends StatelessWidget {
  const _CheckpointPin({required this.checkpoint});

  final Checkpoint checkpoint;

  @override
  Widget build(BuildContext context) {
    final discovered = checkpoint.isDiscovered;

    return Container(
      decoration: BoxDecoration(
        color: discovered ? AppColors.success : AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        discovered ? Icons.check_rounded : Icons.qr_code_2_rounded,
        size: 18,
        color: discovered ? Colors.white : AppColors.gold,
      ),
    );
  }
}

class _PlayerPin extends StatelessWidget {
  const _PlayerPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.info,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.info.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bilah ringkas: berapa checkpoint ditemukan dan misi apa yang sedang berjalan.
class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.state});

  final ExploreState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mission = state.activeMission;
    final total = state.checkpoints.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mission?.title ?? 'Semua misi selesai',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${state.discoveredCount}/$total',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total > 0 ? state.discoveredCount / total : 0,
              minHeight: 8,
              backgroundColor: AppColors.surfaceMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            state.isAllDiscovered
                ? 'Barakallahu fiik — seluruh checkpoint telah Anda temukan!'
                : mission?.description ??
                    'Dekati checkpoint lalu pindai QR untuk menemukan tokoh.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CheckpointTile extends StatelessWidget {
  const _CheckpointTile({required this.checkpoint, this.onTap});

  final Checkpoint checkpoint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discovered = checkpoint.isDiscovered;
    final inRange = checkpoint.isInRange ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: inRange && !discovered
                  ? AppColors.gold
                  : AppColors.surfaceMuted,
              width: inRange && !discovered ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: discovered
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  discovered
                      ? Icons.verified_rounded
                      : Icons.location_on_outlined,
                  color: discovered ? AppColors.success : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      checkpoint.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    // Tetap dipangkas satu baris agar daftarnya rapat; teks
                    // utuhnya ada di lembar rincian saat baris ini diketuk.
                    Text(
                      discovered
                          ? checkpoint.collectiblePreview.name
                          : checkpoint.hint ?? 'Belum ditemukan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    checkpoint.distanceLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: inRange ? AppColors.gold : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (inRange && !discovered)
                    Text(
                      'Siap dipindai',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: AppColors.gold),
                    ),
                ],
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
