import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/distance.dart';
import '../cubit/geofence_cubit.dart';

/// Lapisan yang menutup peta ketika pemain berada di luar area masjid.
///
/// Yang ditutup hanya peta — dan itu memang satu-satunya bagian yang tidak
/// masuk akal ditampilkan dari jauh. Petanya sendiri tetap tergambar di
/// belakang, hanya dikaburkan: menghapusnya sama sekali akan membuang satu
/// hal yang justru berguna di sini, yaitu gambaran di mana pemain berdiri
/// sekarang relatif terhadap masjid yang harus ia tuju.
///
/// Isi kartunya menjawab satu pertanyaan saja: seberapa jauh lagi. Nama masjid
/// dan jaraknya diletakkan paling besar karena itulah yang menentukan apakah
/// seseorang memutuskan berjalan kaki, naik kendaraan, atau menunda.
class CoverageNotice extends StatelessWidget {
  const CoverageNotice({
    required this.state,
    required this.onRecheck,
    this.onShowSite,
    super.key,
  });

  final GeofenceState state;

  /// Memeriksa ulang posisi sekarang juga, melewati jeda otomatis.
  final Future<void> Function() onRecheck;

  /// Membawa kamera peta ke masjid terdekat. Null bila peta tidak tersedia.
  final VoidCallback? onShowSite;

  @override
  Widget build(BuildContext context) {
    final nearest = state.nearest;

    return Stack(
      children: [
        // Peta tetap hidup di belakang, cukup kabur untuk menandakan bahwa ia
        // belum bisa dipakai, tetapi masih terbaca sebagai peta.
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: ColoredBox(
                color: AppColors.primaryDark.withValues(alpha: 0.45),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            // Kartu naik dan membesar sedikit saat muncul. Lapisan ini
            // menggantikan peta secara tiba-tiba ketika pemain melangkah
            // keluar area; tanpa gerakan, pergantiannya terbaca seperti
            // aplikasi yang tersendat, bukan seperti sesuatu yang menutup.
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - t)),
                  child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
                ),
              ),
              child: _NoticeCard(
                nearest: nearest,
                locationCount: state.sites.length,
                isChecking: state.stage == GeofenceStage.locating,
                onRecheck: onRecheck,
                onShowSite: onShowSite,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.nearest,
    required this.locationCount,
    required this.isChecking,
    required this.onRecheck,
    this.onShowSite,
  });

  final NearestSite? nearest;

  /// Berapa lokasi yang tersedia seluruhnya.
  ///
  /// Menentukan apakah pintu ke daftar lokasi ditawarkan sama sekali: dengan
  /// satu lokasi, "lihat semua lokasi" hanya membawa pemain ke daftar berisi
  /// masjid yang sudah disebut namanya di kartu ini.
  final int locationCount;

  final bool isChecking;
  final Future<void> Function() onRecheck;
  final VoidCallback? onShowSite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final site = nearest?.site;

    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceMuted),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.map_outlined,
              size: 28,
              color: AppColors.goldDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Peta permainan terkunci',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Titik hero hanya muncul saat kamu berada di area lokasi bersejarah. '
            'Hero Collection, Reward Store, dan misi tetap bisa dibuka dari mana saja.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          if (site != null)
            _NearestSiteTile(
              nearest: nearest!,
              onShowSite: onShowSite,
            )
          else
            _UnknownDistanceTile(isChecking: isChecking),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isChecking ? null : () => onRecheck(),
                  icon: isChecking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(isChecking ? 'Memeriksa…' : 'Periksa lokasi'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.rewards),
                  icon: const Icon(Icons.redeem_rounded, size: 18),
                  label: const Text('Reward'),
                ),
              ),
            ],
          ),
          if (locationCount > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => context.push(AppRoutes.locations),
                icon: const Icon(Icons.travel_explore_rounded, size: 18),
                label: Text('Lihat $locationCount lokasi lainnya'),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Lokasi diperiksa otomatis — peta terbuka sendiri saat Anda tiba.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Masjid terdekat yang bisa dimainkan, beserta sisa jaraknya.
class _NearestSiteTile extends StatelessWidget {
  const _NearestSiteTile({required this.nearest, this.onShowSite});

  final NearestSite nearest;
  final VoidCallback? onShowSite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final site = nearest.site;

    // Yang ditampilkan adalah jarak sampai *tepi* area bermain, bukan sampai
    // titik tengah masjid. Selisihnya bisa 250 m — cukup besar untuk membuat
    // seseorang mengira masih jauh padahal tinggal menyeberang jalan.
    final remaining = nearest.metersToEnter;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      child: Column(
        children: [
          Text(
            'Lokasi terdekat yang bisa dimainkan',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            site.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (site.city != null) ...[
            const SizedBox(height: 2),
            Text(
              site.city!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // Jarak dihitung ulang pada setiap pembaruan GPS, jadi angkanya
              // memang bergerak sementara pemain berjalan. Dianimasikan supaya
              // ia terlihat merapat, bukan melompat — satu-satunya umpan balik
              // yang memberi tahu bahwa berjalan ke arah ini memang benar.
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: remaining, end: remaining),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, value, _) => Text(
                  formatDistance(value),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'lagi',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Area bermain berjari-jari ${site.radiusMeters} m '
            'dari titik pusat lokasi.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: AppColors.textMuted),
          ),
          if (onShowSite != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onShowSite,
              icon: const Icon(Icons.place_outlined, size: 18),
              label: const Text('Tunjukkan di peta'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Belum ada jarak yang bisa disebutkan — GPS atau daftar masjid belum siap.
class _UnknownDistanceTile extends StatelessWidget {
  const _UnknownDistanceTile({required this.isChecking});

  final bool isChecking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      child: Text(
        isChecking
            ? 'Mencari lokasi terdekat…'
            : 'Jarak ke lokasi terdekat belum diketahui. Aktifkan GPS lalu '
                'periksa ulang.',
        textAlign: TextAlign.center,
        style:
            theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
