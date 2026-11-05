import 'package:flutter/material.dart';

/// Palet warna NUSAVERSE.
///
/// Diturunkan dari identitas merek di konsep produk:
///
/// | Nama           | Kode      | Makna                              |
/// | -------------- | --------- | ---------------------------------- |
/// | Hero Red       | `#D92332` | Keberanian dan identitas nasional  |
/// | Unity White    | `#F8F8F4` | Persatuan dan keterbukaan          |
/// | Victory Gold   | `#F4B52B` | Prestasi dan reward                |
/// | Nusa Navy      | `#17345E` | Teknologi dan kepercayaan          |
/// | Explorer Green | `#20A67A` | Eksplorasi dan alam                |
///
/// Nama token lama (`primary`, `gold`, `cream`, …) dipertahankan agar seluruh
/// layar ikut berganti warna tanpa disentuh satu per satu: `primary` kini
/// Nusa Navy, `gold` kini Victory Gold, `cream` kini Unity White.
class AppColors {
  const AppColors._();

  // ── Warna merek ───────────────────────────────────────────────
  static const Color heroRed = Color(0xFFD92332);
  static const Color unityWhite = Color(0xFFF8F8F4);
  static const Color victoryGold = Color(0xFFF4B52B);
  static const Color nusaNavy = Color(0xFF17345E);
  static const Color explorerGreen = Color(0xFF20A67A);

  // ── Warna utama ───────────────────────────────────────────────
  static const Color primary = nusaNavy;
  static const Color primaryLight = Color(0xFF2A5490);
  static const Color primaryDark = Color(0xFF0F2340);

  static const Color gold = victoryGold;
  static const Color goldLight = Color(0xFFF8CD6A);
  static const Color goldDark = Color(0xFFB9820F);

  /// Aksen keberanian — tombol aksi penting dan penanda merah-putih.
  static const Color accent = heroRed;

  // ── Permukaan ─────────────────────────────────────────────────
  static const Color cream = unityWhite;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFECEDE6);
  static const Color darkSurface = Color(0xFF0B1729);
  static const Color darkSurfaceElevated = Color(0xFF14243D);

  // ── Teks ──────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF16202E);
  static const Color textSecondary = Color(0xFF55606F);
  static const Color textMuted = Color(0xFF8A93A0);
  static const Color textOnDark = Color(0xFFF8F8F4);

  // ── Semantik ──────────────────────────────────────────────────
  static const Color success = explorerGreen;
  static const Color warning = Color(0xFFE08A1E);
  static const Color danger = heroRed;
  static const Color info = Color(0xFF2E6F8E);

  // ── Kelangkaan Hero Card ──────────────────────────────────────
  // Mekanisme permainan, bukan ukuran jasa seorang pahlawan.
  static const Color rarityCommon = Color(0xFF6B7785);
  static const Color rarityRare = Color(0xFF2D6DA3);
  static const Color rarityEpic = Color(0xFF7A4BA8);
  static const Color rarityLegendary = Color(0xFFE0A21C);

  /// Warna aksen untuk sebuah rarity. Menerima nilai enum backend
  /// (`COMMON`, `RARE`, `EPIC`, `LEGENDARY`).
  static Color rarity(String value) => switch (value.toUpperCase()) {
        'LEGENDARY' => rarityLegendary,
        'EPIC' => rarityEpic,
        'RARE' => rarityRare,
        _ => rarityCommon,
      };

  /// Gradien untuk bingkai kartu koleksi.
  static LinearGradient rarityGradient(String value) {
    final base = rarity(value);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [base, Color.lerp(base, Colors.black, 0.35)!],
    );
  }

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryDark, primary],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [goldDark, gold, goldLight],
  );

  /// Garis merah-putih — penanda identitas nasional pada kartu dan kepala layar.
  static const LinearGradient redWhite = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [heroRed, heroRed, unityWhite, unityWhite],
    stops: [0, 0.5, 0.5, 1],
  );
}
