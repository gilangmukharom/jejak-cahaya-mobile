import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../models/enums.dart';

/// Potret tokoh, dipetakan dari slug ke berkas yang dibundel bersama aplikasi.
///
/// ## Kenapa dibundel, bukan diambil dari `imageUrl`
///
/// Skema sudah menyediakan `Collectible.imageUrl`, dan secara arsitektur itulah
/// tempat yang "benar". Tetapi layar yang memakai potret ini muncul tepat
/// setelah pemain memindai QR di pelataran masjid — tempat sinyal kerap buruk.
/// Gambar yang gagal dimuat mengubah layar imbalan menjadi kotak kosong, persis
/// pada momen yang paling ingin dirayakan. Alasannya sama dengan yang membuat
/// basemap peta ikut dibundel.
///
/// ## Kenapa pemetaannya ditulis satu per satu
///
/// Nama berkas sumbernya tidak sama dengan slug — "Ibnu Batutah" untuk
/// `ibnu-battuta`, "Muh Al Fatih" untuk `muhammad-al-fatih`. Mencocokkan secara
/// samar akan berjalan hari ini lalu meleset diam-diam begitu ada tokoh baru
/// yang namanya berdekatan. Peta eksplisit gagal dengan jujur: slug yang tidak
/// dikenal jatuh ke ikon, bukan ke potret orang lain.
///
/// Tokoh yang ditambahkan lewat panel admin belum punya potret dan akan memakai
/// ikon sampai asetnya ikut dibundel pada rilis berikutnya.
class CollectiblePortrait extends StatelessWidget {
  const CollectiblePortrait({
    required this.slug,
    required this.type,
    required this.rarityValue,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.iconSize = 56,
    this.name,
    super.key,
  });

  final String slug;
  final CollectibleType type;
  final String rarityValue;

  final BoxFit fit;
  final Alignment alignment;

  /// Ukuran ikon pengganti bila potretnya belum ada.
  final double iconSize;

  /// Nama pahlawan. Bila diisi dan potretnya belum ada, kartu menampilkan
  /// monogram inisial bergaya Hero Card alih-alih ikon orang generik.
  final String? name;

  ///
  /// Kosong sejak rebrand NUSAVERSE: potret tokoh lama sudah dicabut, dan
  /// potret pahlawan nasional belum dibuat — sampai ada, kartunya memakai
  /// ikon. Menambah potret: lihat assets/characters/README.md.
  static const Map<String, String> _assets = {};

  static bool hasPortrait(String slug) => _assets.containsKey(slug);

  /// Seluruh berkas potret yang dipetakan — dipakai tes bundel.
  @visibleForTesting
  static Iterable<String> get mappedAssets => _assets.values;

  @override
  Widget build(BuildContext context) {
    final asset = _assets[slug];

    if (asset == null) {
      final initials = _initials(name);
      if (initials != null && type != CollectibleType.artifact) {
        return Center(
          child: _Monogram(
            initials: initials,
            color: AppColors.rarity(rarityValue),
            size: iconSize * 1.5,
          ),
        );
      }
      return Center(
        child: Icon(
          type == CollectibleType.artifact
              ? Icons.museum_rounded
              : Icons.person_rounded,
          size: iconSize,
          color: AppColors.rarity(rarityValue).withValues(alpha: 0.85),
        ),
      );
    }

    return Image.asset(
      asset,
      fit: fit,
      alignment: alignment,
      // Potret ditampilkan jauh lebih kecil dari ukuran aslinya; tanpa ini
      // tepinya bergerigi saat diperkecil.
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Ilustrasi $slug',
    );
  }

  /// Inisial dua huruf dari nama, mengabaikan gelar seperti "Ir.", "dr.",
  /// "Drs.", "Mr.", dan "R.A." — "Ir. Soekarno" → "S", "Mohammad Hatta" → "MH".
  static String? _initials(String? name) {
    if (name == null) return null;
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !w.endsWith('.'))
        .toList();
    if (words.isEmpty) return null;
    final first = words.first.characters.first;
    if (words.length == 1) return first.toUpperCase();
    return (first + words.last.characters.first).toUpperCase();
  }
}

/// Monogram Hero Card: inisial emas dalam cincin warna kelangkaan, dengan
/// garis merah-putih di bawahnya — pengganti sementara ilustrasi pahlawan.
class _Monogram extends StatelessWidget {
  const _Monogram(
      {required this.initials, required this.color, required this.size});

  final String initials;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryLight, AppColors.primaryDark],
            ),
            border: Border.all(color: color, width: size * 0.05),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: size * 0.18),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TextStyle(
              color: AppColors.gold,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        SizedBox(height: size * 0.08),
        Container(
          width: size * 0.42,
          height: size * 0.07,
          decoration: BoxDecoration(
            gradient: AppColors.redWhite,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
