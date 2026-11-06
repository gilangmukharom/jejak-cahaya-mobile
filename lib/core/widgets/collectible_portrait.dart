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
    super.key,
  });

  final String slug;
  final CollectibleType type;
  final String rarityValue;

  final BoxFit fit;
  final Alignment alignment;

  /// Ukuran ikon pengganti bila potretnya belum ada.
  final double iconSize;

  static const Map<String, String> _assets = {
    'bilal-bin-rabah': 'assets/characters/bilal-bin-rabah.webp',
    'ibnu-battuta': 'assets/characters/ibnu-battuta.webp',
    'ibnu-sina': 'assets/characters/ibnu-sina.webp',
    'muhammad-al-fatih': 'assets/characters/muhammad-al-fatih.webp',
    'salahuddin-al-ayyubi': 'assets/characters/salahuddin-al-ayyubi.webp',
    'sunan-kalijaga': 'assets/characters/sunan-kalijaga.webp',
  };

  /// Dipakai pengujian untuk memastikan tiap slug pada seed punya potret.
  static bool hasPortrait(String slug) => _assets.containsKey(slug);

  @override
  Widget build(BuildContext context) {
    final asset = _assets[slug];

    if (asset == null) {
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
}
