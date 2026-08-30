import 'package:flutter/material.dart';

/// Palet warna Jejak Cahaya.
///
/// Hijau tua dan emas diambil dari identitas visual aplikasi — nuansa yang
/// lazim pada arsitektur masjid, dan cukup gelap untuk menjaga keterbacaan peta
/// di bawah sinar matahari langsung, kondisi utama saat aplikasi ini dipakai.
class AppColors {
  const AppColors._();

  // ── Warna utama ───────────────────────────────────────────────
  static const Color primary = Color(0xFF0B3D2E);
  static const Color primaryLight = Color(0xFF16624A);
  static const Color primaryDark = Color(0xFF06251C);

  static const Color gold = Color(0xFFC9A24B);
  static const Color goldLight = Color(0xFFE0C378);
  static const Color goldDark = Color(0xFF9B7A2E);

  // ── Permukaan ─────────────────────────────────────────────────
  static const Color cream = Color(0xFFF6F2E9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF0EBE0);
  static const Color darkSurface = Color(0xFF0F1A16);
  static const Color darkSurfaceElevated = Color(0xFF17251F);

  // ── Teks ──────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A211E);
  static const Color textSecondary = Color(0xFF5A6560);
  static const Color textMuted = Color(0xFF8E9793);
  static const Color textOnDark = Color(0xFFF3F1EA);

  // ── Semantik ──────────────────────────────────────────────────
  static const Color success = Color(0xFF2E7D5B);
  static const Color warning = Color(0xFFD9902F);
  static const Color danger = Color(0xFFC0392B);
  static const Color info = Color(0xFF2E6F8E);

  // ── Kelangkaan kartu koleksi ──────────────────────────────────
  static const Color rarityCommon = Color(0xFF6B7D74);
  static const Color rarityRare = Color(0xFF2D6DA3);
  static const Color rarityEpic = Color(0xFF7A4BA8);
  static const Color rarityLegendary = Color(0xFFC9922B);

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
}
