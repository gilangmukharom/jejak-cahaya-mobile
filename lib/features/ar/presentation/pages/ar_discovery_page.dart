import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/scan_result.dart';
import '../widgets/ar_experience.dart';

/// Layar pertama setelah QR checkpoint berhasil dipindai: tokohnya muncul di
/// sekitar pemain dalam AR, lengkap dengan penjelasannya.
///
/// Hadiah (XP, kenaikan level, pencapaian) dan quiz tetap tinggal di layar
/// penemuan, dan layar itu hanya bisa dicapai lewat sini. Karena itu gestur
/// kembali tidak menutup layar ini begitu saja, melainkan meneruskan pemain ke
/// layar penemuan — sekali terlewat, quiz tokohnya tidak bisa diulang dari
/// pemindai.
class ArDiscoveryPage extends StatelessWidget {
  const ArDiscoveryPage({required this.result, super.key});

  final ScanResult result;

  void _continue(BuildContext context) =>
      context.pushReplacement(AppRoutes.discoveryResult);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _continue(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: ArExperience(
          collectible: result.collectible,
          checkpointName: result.checkpointName,
          onBack: () => _continue(context),
          primaryAction: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _continue(context),
              icon: const Icon(Icons.card_giftcard_rounded, size: 20),
              label: Text('Klaim +${result.xpEarned} XP & Lanjut'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.primaryDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
