import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/game_map_style.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/checkpoint.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/scan_result_holder.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../data/game_repository.dart';
import '../cubit/explore_cubit.dart';
import '../cubit/geofence_cubit.dart';
import '../widgets/checkpoint_detail_sheet.dart';
import '../widgets/coverage_notice.dart';
import '../widgets/checkpoint_radar.dart';
import '../widgets/game_map_view.dart';
import 'home_shell.dart';

/// Layar utama permainan.
///
/// Petanya bukan salah satu isi halaman, melainkan **panggung tempat permainan
/// berlangsung**: ia memenuhi layar dari tepi ke tepi, dan segala hal lain —
/// misi yang berjalan, radar, daftar checkpoint — mengambang di atasnya.
///
/// Susunan itu dipilih supaya perhatian pemain berada di tempat yang benar.
/// Permainan ini menuntut orang berjalan ke sebuah titik; yang paling harus
/// terlihat adalah di mana ia berdiri sekarang dan ke mana ia harus melangkah,
/// bukan daftar yang harus digulir. Daftar itu tetap ada, satu tarikan jari di
/// bawah, untuk saat pemain memang ingin membacanya.
class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final mosqueId = sl<AppPreferences>().lastMosqueId;

    return MultiBlocProvider(
      providers: [
        // Cubit geofence berumur sepanjang aplikasi: layar ini ikut membacanya,
        // bukan membuat yang baru, supaya jawaban "di dalam / di luar" yang
        // dilihat peta persis sama dengan yang dilihat gerbang dan pemindai.
        BlocProvider<GeofenceCubit>.value(value: sl<GeofenceCubit>()),
        BlocProvider<ExploreCubit>(
          create: (_) {
            final cubit = ExploreCubit(
              repository: sl<GameRepository>(),
              locationService: sl<LocationService>(),
              scanResults: sl<ScanResultHolder>(),
            );
            if (mosqueId != null) cubit.load(mosqueId);
            return cubit;
          },
        ),
      ],
      child: const _ExploreView(),
    );
  }
}

class _ExploreView extends StatefulWidget {
  const _ExploreView();

  @override
  State<_ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<_ExploreView> {
  /// Tombol pusatkan berada di luar peta, jadi memerintahkannya memerlukan
  /// pegangan langsung ke State peta.
  final GlobalKey<GameMapViewState> _mapKey = GlobalKey<GameMapViewState>();

  /// Tombol pusatkan hanya muncul ketika peta memang tidak lagi mengikuti
  /// pemain. Tombol yang selalu terlihat padahal tidak ada yang perlu
  /// dipusatkan hanya menambah benda di layar.
  bool _isFollowing = true;

  void _openCheckpoint(Checkpoint checkpoint) =>
      CheckpointDetailSheet.show(context, checkpoint);

  /// Masjid yang sedang dievaluasi, dari mana pun yang lebih dulu diketahui.
  String? _mosqueIdOf(GeofenceState geofence) =>
      geofence.mosque?.id ??
      geofence.nearest?.mosque.id ??
      sl<AppPreferences>().lastMosqueId;

  @override
  Widget build(BuildContext context) {
    // Ruang yang ditempati bilah navigasi mengambang milik cangkang. Peta
    // sengaja tergambar sampai ke belakangnya — hanya antarmuka yang perlu
    // menghindarinya.
    final reservedBottom = HomeShell.reservedBottom(context);

    return Scaffold(
      // Warna rumput yang sama dengan tema peta, supaya tidak ada kilatan putih
      // di sela-sela pemuatan.
      backgroundColor: GameMapStyle.groundColor,
      body: BlocConsumer<GeofenceCubit, GeofenceState>(
        // Checkpoint baru diambil ketika areanya benar-benar terbuka, atau
        // ketika masjid yang dituju berganti. Memuatnya lebih awal hanya akan
        // membuang permintaan: server menolak checkpoint bagi pemain di luar
        // area, dan jawabannya tidak bisa ditampilkan pun kalau diberikan.
        listenWhen: (previous, current) =>
            previous.isUnlocked != current.isUnlocked ||
            previous.mosque?.id != current.mosque?.id,
        listener: (context, geofence) {
          final mosqueId = _mosqueIdOf(geofence);
          if (geofence.isUnlocked && mosqueId != null) {
            context.read<ExploreCubit>().load(mosqueId);
          }
        },
        builder: (context, geofence) {
          final mosqueId = _mosqueIdOf(geofence);
          final mosque = geofence.mosque ?? geofence.nearest?.mosque;

          return BlocBuilder<ExploreCubit, ExploreState>(
            builder: (context, state) {
              final isUnlocked = geofence.isUnlocked;
              final target = isUnlocked ? state.nearestPending : null;

              // Selama terkunci, posisi pemain datang dari cubit geofence —
              // ExploreCubit belum berlangganan GPS karena belum ada apa pun
              // yang perlu dimuat.
              final position = state.position ?? geofence.position;

              return Stack(
                children: [
                  Positioned.fill(
                    child: GameMapView(
                      key: _mapKey,
                      checkpoints: isUnlocked ? state.checkpoints : const [],
                      position: position,
                      target: target,
                      mosqueCenter: mosque == null
                          ? null
                          : LatLng(mosque.latitude, mosque.longitude),
                      onCheckpointTap: _openCheckpoint,
                      onFollowChanged: (following) {
                        if (following == _isFollowing) return;
                        setState(() => _isFollowing = following);
                      },
                    ),
                  ),
                  if (!isUnlocked)
                    Positioned.fill(
                      child: CoverageNotice(
                        state: geofence,
                        onRecheck: () =>
                            context.read<GeofenceCubit>().refresh(),
                        onShowMosque: mosque == null
                            ? null
                            : () => _mapKey.currentState?.focusOn(
                                  LatLng(mosque.latitude, mosque.longitude),
                                ),
                      ),
                    ),
                  if (isUnlocked) ...[
                    // Gelap tipis di tepi atas dan bawah. Antarmuka putih yang
                    // mengambang di atas peta terang akan hilang tenggelam
                    // tanpa ini.
                    const Positioned.fill(child: _MapScrim()),

                    _TopHud(state: state, geofence: geofence),

                    _MapControls(
                      bottom: reservedBottom + _sheetPeekHeight + 76,
                      isFollowing: _isFollowing,
                      onRecenter: () => _mapKey.currentState?.recenter(),
                    ),

                    if (target != null)
                      _TargetChip(
                        checkpoint: target,
                        bottom: reservedBottom + _sheetPeekHeight + 12,
                        onTap: () => (target.isInRange ?? false)
                            ? context.push(AppRoutes.scanner)
                            : _openCheckpoint(target),
                      ),

                    Padding(
                      padding: EdgeInsets.only(bottom: reservedBottom),
                      child: _CheckpointSheet(
                        state: state,
                        onCheckpointTap: _openCheckpoint,
                        onRefresh: () async {
                          if (mosqueId != null) {
                            await context.read<ExploreCubit>().load(mosqueId);
                          }
                        },
                      ),
                    ),

                    // Keadaan luar biasa digambar paling akhir, di atas
                    // segalanya.
                    if (state.isLoading && state.checkpoints.isEmpty)
                      const _StatusPill(
                        icon: Icons.satellite_alt_rounded,
                        message: 'Mencari sinyal & memuat checkpoint…',
                      ),

                    if (state.failure != null && state.checkpoints.isEmpty)
                      _LoadFailureOverlay(
                        message: state.failure!.message,
                        onRetry: () {
                          if (mosqueId != null) {
                            context.read<ExploreCubit>().load(mosqueId);
                          }
                        },
                      ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Tinggi bagian lembar checkpoint yang mengintip saat tertutup.
const double _sheetPeekHeight = 92;

/// Lapisan gelap tipis di tepi atas dan bawah peta.
class _MapScrim extends StatelessWidget {
  const _MapScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.18, 0.72, 1],
            colors: [
              Colors.black.withValues(alpha: 0.22),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.14),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bilah misi yang mengambang di tepi atas.
///
/// Isinya dibatasi pada satu pertanyaan: misi apa yang sedang dijalani, dan
/// berapa banyak yang sudah selesai. Uraian misinya sengaja tidak ikut — di
/// layar ini pemain sedang berjalan, bukan membaca.
///
/// Sejak tab Misi digantikan Ibadah, bilah ini juga menjadi pintu masuk ke
/// daftar misi: mengetuknya membuka halaman yang dulu ada di bilah bawah.
class _TopHud extends StatelessWidget {
  const _TopHud({required this.state, required this.geofence});

  final ExploreState state;
  final GeofenceState geofence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = state.checkpoints.length;
    final mission = state.activeMission;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nama lokasi berada di atas bilah misi, bukan di dalamnya.
            // Permainan berjalan di banyak masjid sekarang, dan bilah misi
            // menjawab pertanyaan yang berbeda — "apa yang sedang saya
            // kerjakan", bukan "saya sedang di mana".
            if (geofence.mosque != null) ...[
              _LocationChip(geofence: geofence),
              const SizedBox(height: 8),
            ],
            _FloatingSurface(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => context.push(AppRoutes.missions),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_rounded,
                          size: 19, color: AppColors.primary),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              mission?.title ?? 'Semua misi selesai',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: total > 0
                                    ? state.discoveredCount / total
                                    : 0,
                                minHeight: 5,
                                backgroundColor: AppColors.surfaceMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${state.discoveredCount}/$total',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded,
                          size: 20, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ),
            if (state.failure != null && state.checkpoints.isNotEmpty) ...[
              const SizedBox(height: 8),
              _OfflineBanner(message: state.failure!.message),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lokasi yang sedang dibuka, sekaligus pintu ke daftar lokasi.
///
/// Muncul di setiap layar peta, bukan hanya saat ada beberapa lokasi. Nama
/// masjid adalah konteks bagi seluruh isi layar di bawahnya — checkpoint,
/// misi, dan jarak semuanya milik satu tempat — dan menyembunyikannya ketika
/// kebetulan baru ada satu lokasi berarti pemain harus belajar dua tata letak
/// yang berbeda begitu lokasi kedua ditambahkan.
class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.geofence});

  final GeofenceState geofence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mosque = geofence.mosque;
    if (mosque == null) return const SizedBox.shrink();

    // Pemain sedang melihat lokasi yang ia pilih sendiri, bukan yang terdekat.
    // Perlu dikatakan: tanpa itu, layar yang menyatakan "di luar area" terbaca
    // seolah GPS-nya keliru, padahal ia memang sedang menengok masjid lain.
    final isPinned = geofence.isPinned;

    return _FloatingSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push(AppRoutes.locations),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
          child: Row(
            children: [
              Icon(
                isPinned ? Icons.push_pin_rounded : Icons.mosque_rounded,
                size: 17,
                color: isPinned ? AppColors.goldDark : AppColors.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mosque.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      isPinned
                          ? 'Lokasi pilihan Anda · ketuk untuk ganti'
                          : 'Lokasi terdekat · ketuk untuk lihat semua',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isPinned
                            ? AppColors.goldDark
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.unfold_more_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol-tombol yang menempel di tepi kanan peta.
class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.bottom,
    required this.isFollowing,
    required this.onRecenter,
  });

  final double bottom;
  final bool isFollowing;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 14,
      bottom: bottom,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        offset: isFollowing ? const Offset(1.4, 0) : Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: isFollowing ? 0 : 1,
          child: Semantics(
            button: true,
            label: 'Pusatkan peta ke posisi saya',
            child: Material(
              color: AppColors.surface,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.3),
              child: InkWell(
                onTap: onRecenter,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.my_location_rounded,
                    size: 23,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu ringkas titik tujuan berikutnya, tepat di atas lembar checkpoint.
///
/// Arah tidak lagi ditampilkan di sini sebagai panah — peta di belakangnya
/// sudah memperlihatkannya jauh lebih jelas. Yang tersisa adalah dua hal yang
/// tidak bisa dibaca dari peta: nama titiknya, dan berapa meter lagi.
class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.checkpoint,
    required this.bottom,
    this.onTap,
  });

  final Checkpoint checkpoint;
  final double bottom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inRange = checkpoint.isInRange ?? false;

    return Positioned(
      left: 14,
      bottom: bottom,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            constraints: const BoxConstraints(maxWidth: 232),
            padding: const EdgeInsets.fromLTRB(8, 7, 16, 7),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: inRange
                    ? AppColors.gold
                    : Colors.white.withValues(alpha: 0.16),
                width: inRange ? 1.8 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: inRange
                      ? AppColors.gold.withValues(alpha: 0.42)
                      : Colors.black.withValues(alpha: 0.28),
                  blurRadius: inRange ? 18 : 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    inRange
                        ? Icons.qr_code_scanner_rounded
                        : Icons.directions_walk_rounded,
                    size: 18,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        checkpoint.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.textOnDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        inRange
                            ? 'Ketuk untuk memindai'
                            : checkpoint.distanceLabel,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lembar yang bisa ditarik: radar dan daftar seluruh checkpoint.
class _CheckpointSheet extends StatelessWidget {
  const _CheckpointSheet({
    required this.state,
    required this.onCheckpointTap,
    required this.onRefresh,
  });

  final ExploreState state;
  final void Function(Checkpoint checkpoint) onCheckpointTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = state.nearestPending;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ukuran lembar dinyatakan sebagai pecahan dari tinggi induknya,
        // sementara tinggi bagian yang mengintip adalah angka piksel tetap —
        // jadi pecahannya dihitung dari tinggi yang benar-benar tersedia,
        // bukan ditebak.
        final peek =
            (_sheetPeekHeight / constraints.maxHeight).clamp(0.08, 0.5);

        return DraggableScrollableSheet(
          initialChildSize: peek,
          minChildSize: peek,
          maxChildSize: 0.86,
          snap: true,
          snapSizes: [peek, 0.55],
          builder: (context, scrollController) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: RefreshIndicator(
                onRefresh: onRefresh,
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    // Pegangan dan judul. Keduanya ikut tergulir agar seluruh
                    // isi lembar bisa dijangkau pada tinggi layar terkecil.
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.textMuted.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    state.isAllDiscovered
                                        ? 'Seluruh checkpoint ditemukan'
                                        : 'Checkpoint di Masjid',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (target != null)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        sliver: SliverToBoxAdapter(
                          child: CheckpointRadar(
                            checkpoint: target,
                            onTap: () => context.push(AppRoutes.scanner),
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      sliver: SliverList.separated(
                        itemCount: state.checkpoints.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _CheckpointTile(
                          checkpoint: state.checkpoints[index],
                          onTap: () =>
                              onCheckpointTap(state.checkpoints[index]),
                        ),
                      ),
                    ),
                    // Atribusi lisensi data peta. Tempatnya di sini, bukan di
                    // atas peta: di sana ia akan tertutup lembar ini.
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
                        child: Center(child: MapAttribution()),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Pemberitahuan singkat yang mengambang di tengah layar.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _FloatingSurface(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ditampilkan ketika checkpoint sama sekali gagal dimuat.
///
/// Tanpa daftar checkpoint tidak ada permainan yang bisa dijalankan, jadi
/// keadaan ini memang menutup layar — berbeda dari kegagalan penyegaran yang
/// hanya memunculkan bilah di tepi atas.
class _LoadFailureOverlay extends StatelessWidget {
  const _LoadFailureOverlay({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.cream.withValues(alpha: 0.94),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.explore_off_outlined,
                size: 52,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                'Checkpoint gagal dimuat',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bilah putih membulat dengan bayangan — bentuk dasar seluruh antarmuka yang
/// mengambang di atas peta.
class _FloatingSurface extends StatelessWidget {
  const _FloatingSurface({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
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
        borderRadius: BorderRadius.circular(14),
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
              // Sama dengan penanda di peta: tanda tanya selama tokohnya belum
              // terungkap, centang setelah ditemukan. Urutan kunjungan bebas,
              // jadi tidak ada nomor yang perlu diikuti pemain.
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: discovered
                      ? AppColors.success.withValues(alpha: 0.12)
                      : inRange
                          ? AppColors.gold.withValues(alpha: 0.16)
                          : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: discovered
                    ? const Icon(
                        Icons.verified_rounded,
                        color: AppColors.success,
                      )
                    : Text(
                        '?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: inRange
                              ? AppColors.goldDark
                              : AppColors.textSecondary,
                          height: 1,
                        ),
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
