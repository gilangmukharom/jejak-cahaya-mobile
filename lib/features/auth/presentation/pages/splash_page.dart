import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';

/// Ditampilkan selama sesi tersimpan diperiksa ke server.
///
/// Router menahan pengguna di sini sampai [AuthCubit] selesai memutuskan,
/// sehingga tidak ada kedipan layar masuk bagi pengguna yang masih login.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 2),
                  ),
                  child: const Icon(
                    Icons.mosque_rounded,
                    size: 52,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  AppConfig.appName.toUpperCase(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ISLAMIC EXPLORER',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.7),
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppConfig.appTagline,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.6),
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
