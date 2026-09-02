import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Kredit sponsor: "Supported by — PIK 2 Development".
///
/// ## Kenapa ada keping krem di belakang logo
///
/// Logo PIK 2 memuat kata "DEVELOPMENT" berwarna arang (54, 50, 51). Di atas
/// latar splash yang hijau tua, rasio kontrasnya hanya **1,04 : 1** pada bagian
/// bawah gradien — ambang WCAG untuk teks adalah 4,5 : 1. Kata itu tidak sekadar
/// sulit dibaca; ia lenyap sepenuhnya.
///
/// Jalan keluarnya adalah meletakkan logo di atas keping krem (11,32 : 1),
/// bukan mewarnai ulang logonya. Logo itu milik pihak lain, dan mengubah
/// warnanya agar cocok dengan latar kita bukan wewenang aplikasi ini —
/// sekaligus akan merusak gradasi emas pada wordmark-nya.
///
/// Pada latar terang keping itu tidak diperlukan, jadi [onDark] mematikannya.
class SupportedByPik2 extends StatelessWidget {
  const SupportedByPik2({
    super.key,
    this.onDark = false,
    this.logoWidth = 116,
    this.label = 'Supported by',
  });

  /// True bila diletakkan di atas latar gelap — logo akan diberi keping krem.
  final bool onDark;

  final double logoWidth;

  /// Dikosongkan untuk menampilkan logo tanpa teks pengantar.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final logo = Image.asset(
      'assets/images/logo-pik-2.png',
      width: logoWidth,
      // Logo diperkecil jauh dari ukuran aslinya; tanpa ini garis serif pada
      // wordmark-nya pecah dan bergerigi.
      filterQuality: FilterQuality.medium,
      semanticLabel: 'PIK 2 Development',
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: onDark
                  ? AppColors.textOnDark.withValues(alpha: 0.55)
                  : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 9),
        ],
        if (onDark)
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: logo,
            ),
          )
        else
          logo,
      ],
    );
  }
}
