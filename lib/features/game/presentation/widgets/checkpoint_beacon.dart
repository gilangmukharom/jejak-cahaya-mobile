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
/// Yang membedakan tiap penanda bukan bentuknya melainkan **warnanya**, dan
/// warna itu diambil dari kelangkaan tokoh yang menunggu di baliknya. Backend
/// sengaja tetap mengirim rarity untuk titik yang belum ditemukan — namanya
/// disembunyikan, nilainya tidak — supaya pemain bisa memutuskan sendiri mana
/// yang layak didatangi lebih dulu. Tanpa diwarnai, keterangan itu terbuang.
///
/// Titik yang belum ditemukan hanya menampilkan tanda tanya, bukan nomor.
/// Urutan kunjungan memang bebas, jadi nomor tidak menyampaikan apa pun yang
/// bisa ditindaklanjuti. (Nomor pada berkas QR tetap ada, karena itu dipakai
/// pemasang stiker di lapangan, bukan pemain.)
///
/// Titik yang sudah ditemukan berhenti bergerak, meredup, dan kehilangan
/// seluruh hiasannya. Diam adalah bagian dari umpan baliknya: peta yang seluruh
/// penandanya bergoyang tidak memberi tahu apa pun, sedangkan peta yang hanya
/// menyisakan beberapa penanda hidup langsung memperlihatkan sisa perjalanan.
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
  /// Hanya penanda inilah yang mendapat cincin berputar di tanah. Kalau semua
  /// penanda ikut bersinar, tidak ada satu pun yang menonjol dan pemain
  /// kehilangan petunjuk ke mana harus melangkah berikutnya.
  final bool isTarget;

  final VoidCallback? onTap;

  /// Ukuran kotak penanda. Bagian bawahnya disediakan untuk bayangan dan
  /// rumput, bagian atasnya untuk kilau yang mengorbit.
  static const double width = 66;
  static const double height = 96;

  @override
  State<CheckpointBeacon> createState() => _CheckpointBeaconState();
}

class _CheckpointBeaconState extends State<CheckpointBeacon>
    with SingleTickerProviderStateMixin {
  /// Satu pengendali untuk seluruh gerakan penanda.
  ///
  /// Setiap gerakan mengambil kelipatan bulat dari periode ini — ayunan dua
  /// kali, putaran cincin sekali, kilau sekali — sehingga semuanya kembali ke
  /// titik awal bersamaan dan tidak ada yang tersentak saat pengulangan.
  /// Memakai beberapa pengendali per penanda akan melipatgandakan ticker pada
  /// peta yang memuat belasan titik sekaligus.
  static const Duration _period = Duration(milliseconds: 4000);

  late final AnimationController _motion;

  /// Angka acak yang tetap untuk checkpoint ini.
  ///
  /// Rumput di sekeliling penanda tidak boleh berpindah tempat setiap kali
  /// bingkai digambar ulang. Benihnya dihitung dari kode checkpoint, bukan dari
  /// `hashCode`, agar susunannya sama persis pada setiap kali aplikasi dibuka.
  late final int _seed;

  @override
  void initState() {
    super.initState();
    _seed = widget.checkpoint.code.codeUnits
        .fold<int>(7, (previous, unit) => (previous * 31 + unit) & 0x7fffffff);
    _motion = AnimationController(vsync: this, duration: _period);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant CheckpointBeacon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.checkpoint.isDiscovered) {
      if (_motion.isAnimating) _motion.stop();
      return;
    }
    if (!_motion.isAnimating) _motion.repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkpoint = widget.checkpoint;
    final discovered = checkpoint.isDiscovered;
    final inRange = checkpoint.isInRange ?? false;
    final rarity = AppColors.rarity(checkpoint.collectiblePreview.rarity.value);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, child) {
          final t = _motion.value;

          // Dua ayunan penuh per periode. Sinus dipakai, bukan interpolasi
          // linear, supaya perhentian di puncak dan dasarnya terasa lembut.
          final wave = math.sin(t * 2 * math.pi * 2);
          final lift = discovered ? 0.0 : (widget.isTarget ? 6.0 : 3.0) * wave;

          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Tanah: rumput, bayangan, dan cincin berputar milik titik tujuan.
              Positioned.fill(
                child: CustomPaint(
                  painter: _GroundPainter(
                    progress: t,
                    lift: lift,
                    rarity: rarity,
                    isTarget: widget.isTarget && !discovered,
                    isDiscovered: discovered,
                    seed: _seed,
                  ),
                ),
              ),
              Positioned(bottom: 14 + lift, child: child!),
              // Kilau yang mengorbit di atas cakram — hanya untuk titik yang
              // masih menyimpan tokoh, dan makin ramai pada yang makin langka.
              if (!discovered)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _SparklePainter(
                        progress: t,
                        lift: lift,
                        rarity: rarity,
                        intensity: _rarityWeight(
                          checkpoint.collectiblePreview.rarity.value,
                        ),
                        seed: _seed,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        child: _BeaconDisc(
          checkpoint: checkpoint,
          isTarget: widget.isTarget,
          inRange: inRange,
          rarity: rarity,
        ),
      ),
    );
  }
}

/// Seberapa mencolok sebuah kelangkaan boleh tampil, 0–1.
///
/// Dipakai untuk jumlah dan kecerahan kilau. Tokoh biasa tetap terlihat hidup,
/// tetapi hanya yang legendaris yang benar-benar meminta perhatian.
double _rarityWeight(String value) => switch (value.toUpperCase()) {
      'LEGENDARY' => 1,
      'EPIC' => 0.72,
      'RARE' => 0.45,
      _ => 0.2,
    };

/// Menggambar segala sesuatu yang berada di permukaan tanah.
class _GroundPainter extends CustomPainter {
  const _GroundPainter({
    required this.progress,
    required this.lift,
    required this.rarity,
    required this.isTarget,
    required this.isDiscovered,
    required this.seed,
  });

  final double progress;
  final double lift;
  final Color rarity;
  final bool isTarget;
  final bool isDiscovered;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    // Titik tanah ditempatkan 11 px di atas tepi bawah, bukan tepat di tepinya.
    // Cincin berputar meluas ke bawah dari titik ini, dan tanpa sisa ruang itu
    // busur bagian bawahnya terpotong oleh batas penanda.
    final ground = Offset(size.width / 2, size.height - 11);

    // ── Cincin berputar ─────────────────────────────────────────
    // Tiga busur yang berputar pelan di tanah, seperti penanda lokasi yang
    // sedang "aktif". Hanya titik tujuan berikutnya yang mendapatkannya,
    // sehingga satu putaran di kejauhan sudah cukup memberi tahu ke mana
    // pemain harus melangkah.
    if (isTarget) {
      const double radius = 22;
      final rect = Rect.fromCenter(
        center: ground,
        width: radius * 2,
        height: radius * 0.86,
      );

      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = rarity.withValues(alpha: 0.85);

      final turn = progress * 2 * math.pi;
      for (var i = 0; i < 3; i++) {
        canvas.drawArc(
          rect,
          turn + i * (2 * math.pi / 3),
          math.pi / 3.4,
          false,
          arc,
        );
      }

      // Cahaya lembut di dalam cincin, berdenyut seirama putarannya.
      final glow = 0.10 + 0.06 * math.sin(progress * 2 * math.pi);
      canvas.drawOval(rect, Paint()..color = rarity.withValues(alpha: glow));
    }

    // ── Rumput ──────────────────────────────────────────────────
    // Ditanam hanya di sekeliling penanda, bukan disebar ke seluruh peta.
    // Lapisan ini tidak tahu mana daratan dan mana jalan atau air, jadi rumput
    // yang disebar merata akan tumbuh di tengah jalan raya dan di atas laut.
    // Di sekitar checkpoint tanahnya sudah pasti tanah — dan sekaligus membuat
    // titiknya terasa seperti sebuah tempat, bukan sekadar koordinat.
    final random = math.Random(seed);
    final tufts = isDiscovered ? 3 : 5;

    for (var i = 0; i < tufts; i++) {
      final spread = 16 + random.nextDouble() * 12;
      final side = random.nextBool() ? 1 : -1;
      final dx = side * spread;
      final dy = -1 + random.nextDouble() * 5;
      final height = 5 + random.nextDouble() * 4;

      // Setiap rumpun bergoyang dengan fasenya sendiri; kalau seragam, yang
      // terlihat bukan angin melainkan seluruh peta bergetar.
      final phase = random.nextDouble() * 2 * math.pi;
      final sway = math.sin(progress * 2 * math.pi + phase) * 1.4;

      final base = Offset(ground.dx + dx, ground.dy + dy);
      final blade = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF5FA86B)
            .withValues(alpha: isDiscovered ? 0.35 : 0.62);

      for (var b = -1; b <= 1; b++) {
        canvas.drawLine(
          base.translate(b * 2.0, 0),
          base.translate(b * 2.0 + sway + b * 1.2, -height),
          blade,
        );
      }
    }

    // ── Bayangan ────────────────────────────────────────────────
    // Menyusut saat cakramnya naik, seperti bayangan sungguhan. Digambar
    // paling akhir agar berada di atas rumput yang tumbuh di belakangnya.
    canvas.drawOval(
      Rect.fromCenter(
        center: ground.translate(0, 2),
        width: 24 - lift * 0.7,
        height: 7.5 - lift * 0.2,
      ),
      Paint()
        ..color = Colors.black.withValues(
          alpha: isDiscovered ? 0.16 : 0.24 - lift * 0.008,
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _GroundPainter old) =>
      old.progress != progress ||
      old.lift != lift ||
      old.isTarget != isTarget ||
      old.isDiscovered != isDiscovered ||
      old.rarity != rarity;
}

/// Kilau kecil yang mengorbit di atas cakram.
class _SparklePainter extends CustomPainter {
  const _SparklePainter({
    required this.progress,
    required this.lift,
    required this.rarity,
    required this.intensity,
    required this.seed,
  });

  final double progress;
  final double lift;
  final Color rarity;
  final double intensity;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final count = (2 + intensity * 3).round();
    final center = Offset(size.width / 2, size.height - 40 - lift);
    final random = math.Random(seed + 991);

    for (var i = 0; i < count; i++) {
      final phase = random.nextDouble();
      final t = (progress + phase) % 1.0;

      // Mengorbit mendatar dan sedikit naik-turun, sehingga terbaca melayang
      // mengelilingi cakram alih-alih menempel pada bidang layar.
      final angle = t * 2 * math.pi;
      final orbit = 15 + random.nextDouble() * 7;
      final offset = Offset(
        center.dx + math.cos(angle) * orbit,
        center.dy + math.sin(angle) * 4 - random.nextDouble() * 8,
      );

      // Meredup di paruh belakang orbit — itu yang memberi kesan berputar di
      // belakang cakram, bukan sekadar bergerak dalam lingkaran datar.
      final depth = (math.sin(angle) + 1) / 2;
      final alpha = ((0.25 + 0.65 * depth) * intensity).clamp(0.0, 1.0);
      final radius = 1.1 + depth * 1.3;

      canvas
        ..drawCircle(
          offset,
          radius * 2.6,
          Paint()..color = rarity.withValues(alpha: alpha * 0.22),
        )
        ..drawCircle(
          offset,
          radius,
          Paint()
            ..color = Color.lerp(rarity, Colors.white, 0.55)!
                .withValues(alpha: alpha),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) =>
      old.progress != progress ||
      old.lift != lift ||
      old.intensity != intensity ||
      old.rarity != rarity;
}

class _BeaconDisc extends StatelessWidget {
  const _BeaconDisc({
    required this.checkpoint,
    required this.isTarget,
    required this.inRange,
    required this.rarity,
  });

  final Checkpoint checkpoint;
  final bool isTarget;
  final bool inRange;
  final Color rarity;

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
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: body,
          shape: BoxShape.circle,
          // Bingkainya memakai warna kelangkaan, bukan putih. Inilah yang
          // membuat sebaran titik di peta bisa dibaca sekilas: mana yang
          // menyimpan tokoh biasa, mana yang menyimpan yang langka.
          border: Border.all(
            color: discovered ? Colors.white70 : rarity,
            width: isTarget && !discovered ? 3.2 : 2.6,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            if (!discovered)
              BoxShadow(
                color: rarity.withValues(alpha: isTarget ? 0.55 : 0.3),
                blurRadius: isTarget ? 18 : 10,
                spreadRadius: isTarget ? 2 : 0,
              ),
          ],
        ),
        child: discovered
            ? const Icon(Icons.check_rounded, size: 23, color: Colors.white)
            : Text(
                '?',
                style: TextStyle(
                  color: Color.lerp(rarity, Colors.white, 0.35),
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                  height: 1,
                ),
              ),
      ),
    );
  }
}
