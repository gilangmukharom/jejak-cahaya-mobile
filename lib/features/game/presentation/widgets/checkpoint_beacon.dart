import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/checkpoint.dart';

/// Penanda checkpoint di atas peta permainan.
///
/// Bentuknya bukan pin peta melainkan cakram melayang dengan bayangan di
/// tanah — persis alasan mengapa penanda dalam permainan berbasis lokasi
/// dibuat mengambang: bayangannya menandai titik yang sesungguhnya, sementara
/// cakramnya bebas naik-turun untuk menarik perhatian tanpa menggeser lokasi.
///
/// Titik yang belum ditemukan hanya menampilkan tanda tanya, bukan nomor.
/// Urutan kunjungan memang bebas, jadi nomor tidak menyampaikan apa pun yang
/// bisa ditindaklanjuti — sementara tanda tanya menyampaikan satu-satunya hal
/// yang benar-benar berlaku: tokoh di balik titik ini belum diketahui sampai
/// QR-nya dipindai. (Nomor pada berkas QR tetap ada, karena itu dipakai
/// pemasang stiker di lapangan, bukan pemain.)
///
/// Titik yang sudah ditemukan berubah total — hijau dengan centang, berhenti
/// bergerak, dan meredup. Ketiganya bekerja bersama supaya sekali lirik cukup
/// untuk tahu mana yang masih menyimpan tokoh.
///
/// Pasang dengan `alignment: Alignment.topCenter` agar dasar bayangannya jatuh
/// tepat pada koordinat, dan `rotate: true` agar isinya tetap tegak ketika
/// peta berputar.
class CheckpointBeacon extends StatefulWidget {
  const CheckpointBeacon({
    required this.checkpoint,
    required this.isTarget,
    this.onTap,
    super.key,
  });

  final Checkpoint checkpoint;

  /// Apakah ini titik terdekat yang belum ditemukan — satu-satunya titik yang
  /// sedang diminta permainan untuk didatangi.
  ///
  /// Hanya penanda inilah yang bercahaya. Kalau semua penanda ikut bersinar,
  /// tidak ada satu pun yang menonjol dan pemain kehilangan petunjuk ke mana
  /// harus melangkah berikutnya.
  final bool isTarget;

  final VoidCallback? onTap;

  /// Ukuran kotak penanda. Bagian bawahnya disediakan untuk bayangan tanah.
  static const double width = 58;
  static const double height = 74;

  @override
  State<CheckpointBeacon> createState() => _CheckpointBeaconState();
}

class _CheckpointBeaconState extends State<CheckpointBeacon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant CheckpointBeacon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  /// Titik yang sudah ditemukan berhenti bergerak.
  ///
  /// Diam adalah bagian dari umpan baliknya: peta yang seluruh penandanya
  /// bergoyang tidak memberi tahu apa pun, sedangkan peta yang hanya menyisakan
  /// beberapa penanda hidup langsung memperlihatkan sisa perjalanan.
  void _syncAnimation() {
    if (widget.checkpoint.isDiscovered) {
      if (_bob.isAnimating) _bob.stop();
      return;
    }
    if (!_bob.isAnimating) _bob.repeat();
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkpoint = widget.checkpoint;
    final discovered = checkpoint.isDiscovered;
    final inRange = checkpoint.isInRange ?? false;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _bob,
        builder: (context, child) {
          // Satu siklus sinus penuh: naik, turun, kembali — tanpa hentakan di
          // titik ulang seperti yang terjadi pada interpolasi linear.
          final wave = math.sin(_bob.value * 2 * math.pi);
          final lift = discovered ? 0.0 : (widget.isTarget ? 5.0 : 2.5) * wave;

          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Bayangan tanah — inilah koordinat checkpoint yang sebenarnya.
              // Menyusut saat cakramnya naik, seperti bayangan sungguhan.
              Positioned(
                bottom: 4,
                child: Container(
                  width: 22 - lift * 0.6,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: discovered ? 0.16 : 0.22 - lift * 0.008,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                bottom: 12 + lift,
                child: child!,
              ),
            ],
          );
        },
        child: _BeaconDisc(
          checkpoint: checkpoint,
          isTarget: widget.isTarget,
          inRange: inRange,
        ),
      ),
    );
  }
}

class _BeaconDisc extends StatelessWidget {
  const _BeaconDisc({
    required this.checkpoint,
    required this.isTarget,
    required this.inRange,
  });

  final Checkpoint checkpoint;
  final bool isTarget;
  final bool inRange;

  @override
  Widget build(BuildContext context) {
    final discovered = checkpoint.isDiscovered;

    final Color body;
    if (discovered) {
      body = AppColors.success;
    } else if (inRange) {
      body = AppColors.goldDark;
    } else {
      body = AppColors.primary;
    }

    // Yang sudah ditemukan sengaja diredupkan. Peta yang seluruh penandanya
    // sama pekatnya memaksa pemain membaca satu per satu; dengan yang selesai
    // mundur ke latar, sisa perjalanan terbaca sekali lirik.
    return Opacity(
      opacity: discovered ? 0.72 : 1,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: body,
          shape: BoxShape.circle,
          border: Border.all(
            color: isTarget && !discovered ? AppColors.gold : Colors.white,
            width: isTarget && !discovered ? 3 : 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            // Cahaya keemasan hanya untuk titik tujuan berikutnya.
            if (isTarget && !discovered)
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.55),
                blurRadius: 18,
                spreadRadius: 2,
              ),
          ],
        ),
        child: discovered
            ? const Icon(Icons.check_rounded, size: 22, color: Colors.white)
            : const Text(
                '?',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  height: 1,
                ),
              ),
      ),
    );
  }
}
