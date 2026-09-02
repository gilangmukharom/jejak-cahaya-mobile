import 'package:flutter/material.dart' hide Theme;
import 'package:flutter/material.dart' as material show Theme;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/game_map_style.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/checkpoint.dart';
import '../../../../core/services/basemap_service.dart';
import '../../../../core/services/location_service.dart';
import 'checkpoint_beacon.dart';
import 'game_map_camera.dart';
import 'player_marker.dart';

/// Peta permainan yang memenuhi layar.
///
/// Berbeda dari peta di dalam kartu, peta ini adalah **latar tempat permainan
/// berlangsung**: kamera mengikuti pemain, ikut berputar ke arah ia berjalan,
/// dan seluruh antarmuka lain mengambang di atasnya. Karena itu widget ini
/// tidak punya tinggi tetap — ia mengisi ruang yang diberikan induknya.
///
/// Mode ikuti (follow) mati sendiri begitu pemain menggeser peta dengan jari,
/// dan menyala lagi lewat tombol pusatkan. Tanpa itu, peta akan menarik dirinya
/// kembali ke pemain setiap kali pemain mencoba melihat-lihat sekitar — salah
/// satu hal paling menjengkelkan pada peta yang mengikuti posisi.
class GameMapView extends StatefulWidget {
  const GameMapView({
    required this.checkpoints,
    required this.position,
    this.target,
    this.mosqueCenter,
    this.onCheckpointTap,
    this.onFollowChanged,
    super.key,
  });

  final List<Checkpoint> checkpoints;
  final PlayerPosition? position;

  /// Checkpoint terdekat yang belum ditemukan — satu-satunya yang disorot.
  final Checkpoint? target;

  /// Dipakai sebagai pusat awal ketika GPS belum memberi kabar.
  final LatLng? mosqueCenter;

  final void Function(Checkpoint checkpoint)? onCheckpointTap;

  /// Memberi tahu induk saat mode ikuti berubah, agar tombol pusatkan bisa
  /// muncul dan menghilang.
  final ValueChanged<bool>? onFollowChanged;

  @override
  State<GameMapView> createState() => GameMapViewState();
}

class GameMapViewState extends State<GameMapView>
    with SingleTickerProviderStateMixin {
  final MapController _controller = MapController();
  late final GameMapCamera _camera;

  /// Muatan basemap offline hanya dijalankan sekali per layar.
  late final Future<Basemap> _basemap;

  /// Tema tidak bergantung pada apa pun yang berubah, jadi dibangun sekali.
  /// Membacanya ulang berarti mengurai kembali seluruh daftar layer.
  final Theme _theme = GameMapStyle.build();

  bool _isFollowing = true;

  /// Sudut peta yang terakhir diminta, dipakai agar peta tidak diperintahkan
  /// berputar untuk perubahan arah sebesar derau GPS.
  double _rotationDeg = 0;

  static const double _followZoom = 18.2;

  @override
  void initState() {
    super.initState();
    _camera = GameMapCamera(controller: _controller, vsync: this);
    _basemap = sl<BasemapService>().load();
  }

  @override
  void didUpdateWidget(covariant GameMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position != oldWidget.position) _followPlayer();
  }

  @override
  void dispose() {
    _camera.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Memusatkan kembali peta ke pemain dan menyalakan lagi mode ikuti.
  /// Dipanggil dari luar lewat [GlobalKey] oleh tombol pusatkan.
  void recenter() {
    if (!_isFollowing) {
      setState(() => _isFollowing = true);
      widget.onFollowChanged?.call(true);
    }
    _followPlayer(force: true);
  }

  void _followPlayer({bool force = false}) {
    if (!_isFollowing && !force) return;

    final position = widget.position;
    if (position == null) return;

    // Peta hanya diputar ketika pemain benar-benar berjalan. Lihat
    // `PlayerPosition.headingWhenMoving` untuk alasannya.
    final heading = position.headingWhenMoving;
    if (heading != null) {
      final desired = -heading;
      // Ambang 8° menyaring goyangan arah yang wajar terjadi saat berjalan
      // kaki; tanpanya peta bergetar terus-menerus sepanjang perjalanan.
      if (GameMapCamera.turnSize(from: _rotationDeg, to: desired) > 8) {
        _rotationDeg = desired;
      }
    }

    _camera.animateTo(
      center: LatLng(position.latitude, position.longitude),
      zoom: force ? _followZoom : null,
      rotationDeg: _rotationDeg,
      duration: force
          ? const Duration(milliseconds: 700)
          : const Duration(milliseconds: 1100),
    );
  }

  void _onMapEvent(MapEvent event) {
    // Hanya gerakan yang berasal dari jari pemain yang mematikan mode ikuti.
    // Gerakan dari `_camera` sendiri datang dengan sumber `mapController` dan
    // harus diabaikan, kalau tidak mode ikuti akan mematikan dirinya sendiri
    // pada gerakan pertamanya.
    const gestures = {
      MapEventSource.onDrag,
      MapEventSource.dragStart,
      MapEventSource.multiFingerGestureStart,
      MapEventSource.onMultiFinger,
      MapEventSource.flingAnimationController,
      MapEventSource.doubleTapZoomAnimationController,
      MapEventSource.scrollWheel,
    };
    if (!gestures.contains(event.source)) return;

    _camera.stop();
    if (!_isFollowing) return;

    setState(() => _isFollowing = false);
    widget.onFollowChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.position;
    final center = position != null
        ? LatLng(position.latitude, position.longitude)
        : widget.mosqueCenter ??
            (widget.checkpoints.isNotEmpty
                ? LatLng(
                    widget.checkpoints.first.latitude,
                    widget.checkpoints.first.longitude,
                  )
                : const LatLng(-6.087036, 106.735228));

    return FutureBuilder<Basemap>(
      future: _basemap,
      builder: (context, snapshot) {
        final basemap = snapshot.data;

        return Stack(
          children: [
            Positioned.fill(child: _buildMap(center, position, basemap)),
            if (basemap != null)
              _BasemapNotice(basemap: basemap, position: position),
          ],
        );
      },
    );
  }

  Widget _buildMap(LatLng center, PlayerPosition? position, Basemap? basemap) {
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: _followZoom,
        minZoom: 14,
        maxZoom: 19.5,
        // Latar disamakan dengan warna rumput pada tema. Tanpa ini, sepersekian
        // detik sebelum tile pertama tergambar layar berkedip putih — cukup
        // untuk terlihat seperti kegagalan memuat.
        backgroundColor: GameMapStyle.groundColor,
        onMapReady: () {
          _camera.markReady();
          _followPlayer();
        },
        onMapEvent: _onMapEvent,
        interactionOptions: const InteractionOptions(
          // Putaran peta dikendalikan arah jalan pemain, bukan jari. Memutar
          // dengan dua jari akan langsung dibatalkan oleh pembaruan GPS
          // berikutnya, jadi gerakannya sengaja tidak disediakan sama sekali.
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.flingAnimation,
        ),
      ),
      children: [
        if (basemap != null && basemap.isReady) _buildBasemapLayer(basemap),
        // Disisipkan tepat di atas basemap dan di bawah segala penanda:
        // yang diwarnai waktu adalah pemandangannya, bukan antarmukanya.
        const _TimeOfDayTint(),
        if (widget.target != null) _buildTargetRadius(widget.target!),
        _buildCheckpointMarkers(),
        if (position != null) ..._buildPlayerMarkers(position),
      ],
    );
  }

  /// Basemap vektor offline.
  ///
  /// Hanya dipasang setelah arsipnya benar-benar terbuka. Kegagalannya tidak
  /// lagi berakhir sebagai layar hijau tanpa penjelasan — [_BasemapNotice] yang
  /// menyampaikannya.
  Widget _buildBasemapLayer(Basemap basemap) {
    return VectorTileLayer(
          tileProviders: basemap.providers!,
          theme: _theme,
          // Data dalam arsip berhenti di zoom 15, sementara permainan berlangsung
          // di zoom 18. Mode vektor menggambar ulang geometrinya pada setiap
          // tingkat perbesaran, jadi jalan tetap tajam; mode raster hanya akan
          // memperbesar gambar zoom 15 dan hasilnya kabur.
          layerMode: VectorTileLayerMode.vector,
          // Cache berkas tidak bisa dimatikan lewat API-nya, jadi ia disetel
          // agar berperilaku sebagai salinan sekali-tulis: batas ukurannya
          // ditaruh di atas ukuran arsip, dan masa berlakunya dibuat panjang.
          //
          // Menyetel keduanya ke nol — yang tampak seperti "matikan cache" —
          // justru menghasilkan yang sebaliknya: setiap tile tetap ditulis ke
          // disk, lalu seluruhnya dihapus pada tiap kelipatan 20 penulisan.
          // Untuk aplikasi yang dipakai berjalan kaki, siklus tulis-hapus itu
          // menguras baterai tanpa memberi apa pun.
          fileCacheTtl: const Duration(days: 365),
          fileCacheMaximumSizeInBytes: 12 * 1024 * 1024,
        );
  }

  /// Lingkaran jangkauan di sekitar titik tujuan berikutnya.
  ///
  /// Digambar hanya untuk satu titik, bukan semua. Radius checkpoint bisa
  /// mencapai puluhan meter sementara layar sedekat ini hanya mencakup puluhan
  /// meter juga — menggambar semuanya membuat lingkarannya saling menimpa dan
  /// peta berubah menjadi bidang emas polos.
  Widget _buildTargetRadius(Checkpoint target) {
    return CircleLayer(
      circles: [
        CircleMarker(
          point: LatLng(target.latitude, target.longitude),
          radius: target.radiusMeters.toDouble(),
          useRadiusInMeter: true,
          color: AppColors.gold.withValues(alpha: 0.14),
          borderColor: AppColors.gold.withValues(alpha: 0.8),
          borderStrokeWidth: 2,
        ),
      ],
    );
  }

  Widget _buildCheckpointMarkers() {
    final targetId = widget.target?.id;

    return MarkerLayer(
      markers: [
        for (final checkpoint in widget.checkpoints)
          Marker(
            point: LatLng(checkpoint.latitude, checkpoint.longitude),
            width: CheckpointBeacon.width,
            height: CheckpointBeacon.height,
            // Dasar penanda jatuh tepat pada koordinat, dan angkanya tetap
            // tegak ketika peta berputar mengikuti arah jalan pemain.
            alignment: Alignment.topCenter,
            rotate: true,
            child: CheckpointBeacon(
              checkpoint: checkpoint,
              isTarget: checkpoint.id == targetId,
              onTap: () => widget.onCheckpointTap?.call(checkpoint),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildPlayerMarkers(PlayerPosition position) {
    final point = LatLng(position.latitude, position.longitude);

    return [
      MarkerLayer(
        markers: [
          // Denyut dan kerucut arah: ikut berputar bersama peta.
          Marker(
            point: point,
            width: 132,
            height: 132,
            child: PlayerAura(
              diameter: 132,
              headingDeg: position.headingDeg,
              isMoving: position.isMoving,
            ),
          ),
          // Avatar: tetap tegak.
          Marker(
            point: point,
            width: 30,
            height: 30,
            rotate: true,
            child: const PlayerAvatar(),
          ),
        ],
      ),
    ];
  }
}

/// Mewarnai peta mengikuti waktu setempat.
///
/// Permainan ini dimainkan di luar ruangan, dan langit di atas pemain berubah
/// sepanjang hari. Peta yang warnanya sama pada pukul enam pagi dan pukul
/// delapan malam terasa seperti gambar, bukan seperti tempat.
///
/// Warnanya sengaja tipis. Layar ini dibaca sambil berjalan di bawah matahari
/// langsung, dan lapisan yang terlalu pekat akan menukar suasana dengan
/// keterbacaan — pertukaran yang selalu merugi pada permainan luar ruang.
/// Karena itu pula hanya bidang peta yang diwarnai: penanda checkpoint dan
/// avatar pemain berada di atasnya dan tetap sepenuhnya jernih.
class _TimeOfDayTint extends StatelessWidget {
  const _TimeOfDayTint();

  /// Warna untuk sebuah jam, 0–23.
  ///
  /// Dihitung dari jam saja, bukan dari posisi matahari yang sebenarnya.
  /// Perhitungan astronomis akan lebih tepat, tetapi selisihnya beberapa puluh
  /// menit pada lapisan yang nyaris tembus pandang — tidak ada yang bisa
  /// melihat bedanya.
  static Color _tintFor(int hour) {
    if (hour >= 6 && hour < 16) {
      // Siang: dibiarkan apa adanya. Palet petanya sudah dirancang untuk
      // dilihat di bawah cahaya terang.
      return Colors.transparent;
    }
    if (hour >= 16 && hour < 18) {
      // Sore menjelang magrib — waktu paling ramai di halaman masjid.
      return const Color(0xFFE08A3C).withValues(alpha: 0.16);
    }
    if (hour >= 18 && hour < 20) {
      return const Color(0xFF6B4EA8).withValues(alpha: 0.20);
    }
    if (hour >= 20 || hour < 4) {
      return const Color(0xFF10214A).withValues(alpha: 0.30);
    }
    // Menjelang subuh.
    return const Color(0xFF2E4F86).withValues(alpha: 0.20);
  }

  @override
  Widget build(BuildContext context) {
    final tint = _tintFor(DateTime.now().hour);
    if (tint.a == 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: SizedBox.expand(child: ColoredBox(color: tint)),
    );
  }
}

/// Menjelaskan mengapa peta tampak kosong.
///
/// Bidang hijau tanpa jalan punya dua sebab yang sama sekali berbeda, dan
/// keduanya terlihat persis sama di layar: arsip petanya gagal dimuat, atau
/// pemain sedang berada di luar wilayah yang dipetakan. Tanpa keterangan,
/// satu-satunya cara membedakannya adalah membaca log — sesuatu yang tidak bisa
/// dilakukan orang yang sedang berdiri di halaman masjid.
///
/// Widget ini diam sepenuhnya ketika semuanya berjalan normal.
class _BasemapNotice extends StatelessWidget {
  const _BasemapNotice({required this.basemap, required this.position});

  final Basemap basemap;
  final PlayerPosition? position;

  @override
  Widget build(BuildContext context) {
    final String message;
    final IconData icon;

    if (!basemap.isReady) {
      icon = Icons.layers_clear_rounded;
      message = basemap.failureReason ?? 'Peta offline tidak tersedia.';
    } else {
      final player = position;
      if (player == null || basemap.covers(player.latitude, player.longitude)) {
        return const SizedBox.shrink();
      }
      icon = Icons.travel_explore_rounded;
      // Koordinat pemain ikut ditampilkan karena itulah satu-satunya angka yang
      // dibutuhkan untuk membuat ulang arsip peta agar mencakup tempat ini —
      // lihat assets/map/README.md. Tanpa ditampilkan di sini, angkanya harus
      // dicari lewat aplikasi lain.
      message =
          'Kamu di luar wilayah peta yang dibundel, jadi tidak ada jalan yang '
          'bisa digambar.\n'
          'Posisimu: ${player.latitude.toStringAsFixed(5)}, '
          '${player.longitude.toStringAsFixed(5)}\n'
          'Cakupan peta: ${basemap.coverageLabel}';
    }

    return SafeArea(
      child: Padding(
        // Disisipkan di bawah bilah misi yang mengambang di tepi atas, agar
        // keduanya tidak saling menimpa.
        padding: const EdgeInsets.fromLTRB(14, 86, 14, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 11, 15, 11),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 17, color: AppColors.gold),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.4,
                    ),
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

/// Atribusi OpenStreetMap & Protomaps.
///
/// Wajib menurut lisensi ODbL data OpenStreetMap. Dipisah dari [GameMapView]
/// agar bisa diletakkan di antara elemen antarmuka yang mengambang — di dalam
/// peta, teks ini akan tertimbun lembar checkpoint.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          '© OpenStreetMap · Protomaps',
          style: material.Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: AppColors.textSecondary,
              ),
        ),
      ),
    );
  }
}
