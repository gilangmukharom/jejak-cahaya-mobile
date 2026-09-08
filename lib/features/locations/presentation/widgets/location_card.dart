import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/mosque.dart';
import '../../../../core/utils/distance.dart';
import 'progress_ring.dart';

/// Satu lokasi permainan pada daftar.
///
/// Menjawab tiga pertanyaan sekaligus, dalam urutan yang benar-benar ditanyakan
/// pemain: apakah saya bisa main di sini sekarang (pil status), seberapa jauh
/// (jarak), dan seberapa jauh saya sudah sampai di sana (cincin progres).
///
/// Kartu yang sedang dibuka ditandai bingkai emas alih-alih dipindahkan ke
/// urutan pertama: urutan daftar adalah urutan jarak, dan mengacaknya demi
/// menonjolkan satu kartu akan menghilangkan satu-satunya urutan yang berguna.
class LocationCard extends StatefulWidget {
  const LocationCard({
    required this.mosque,
    required this.isActive,
    required this.onTap,
    this.index = 0,
    super.key,
  });

  final Mosque mosque;

  /// True bila inilah lokasi yang sedang dibuka aplikasi.
  final bool isActive;

  final VoidCallback onTap;

  /// Urutan kartu pada daftar — menentukan jeda animasi masuknya.
  final int index;

  @override
  State<LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<LocationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _entry,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.10),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic));

  /// Menyusut sedikit selama ditekan — satu-satunya umpan balik sentuh yang
  /// terasa langsung pada kartu sebesar ini, karena riak Material-nya
  /// tertutup isi kartu sendiri.
  bool _pressed = false;

  @override
  void initState() {
    super.initState();

    // Kartu masuk berurutan dari atas, bukan serentak. Dengan begitu daftar
    // terbaca sebagai daftar — mata mengikuti satu per satu — alih-alih
    // muncul sebagai satu blok yang harus dipindai ulang dari awal.
    Future<void>.delayed(
      Duration(milliseconds: 60 * widget.index),
      () {
        if (mounted) _entry.forward();
      },
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mosque = widget.mosque;
    final progress = mosque.progress;
    final isInside = mosque.isInside == true;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.975 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isActive
                      ? AppColors.gold
                      : isInside
                          ? AppColors.success.withValues(alpha: 0.45)
                          : AppColors.surfaceMuted,
                  width: widget.isActive ? 1.6 : 1,
                ),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mosque.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              mosque.placeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (progress != null)
                        ProgressRing(
                          value: progress.fraction,
                          label:
                              '${progress.discoveredCheckpoints}/${progress.totalCheckpoints}',
                          isComplete: progress.isCompleted,
                        )
                      else
                        _CountBadge(count: mosque.checkpointCount),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _StatusPill(mosque: mosque),
                      if (mosque.distanceM != null && !isInside)
                        _Chip(
                          icon: Icons.straighten_rounded,
                          label: formatDistance(mosque.distanceM!),
                        ),
                      _Chip(
                        icon: Icons.flag_rounded,
                        label: progress == null
                            ? '${mosque.missionCount} misi'
                            : '${progress.completedMissions}/${progress.totalMissions} misi',
                      ),
                      if (progress != null && progress.xpEarned > 0)
                        _Chip(
                          icon: Icons.bolt_rounded,
                          label: '${progress.xpEarned} XP',
                          tone: AppColors.goldDark,
                          background: AppColors.gold.withValues(alpha: 0.14),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pil status: satu-satunya baris yang menentukan apakah pemain bisa langsung
/// bermain, jadi diberi warna paling kuat di kartu.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.mosque});

  final Mosque mosque;

  @override
  Widget build(BuildContext context) {
    final isInside = mosque.isInside;

    // Jarak belum diketahui — GPS belum mengunci, atau pemain menolak izin
    // lokasi. Menebak "di luar area" di keadaan itu akan salah separuh waktu.
    if (isInside == null) {
      return const _Chip(
        icon: Icons.location_searching_rounded,
        label: 'Jarak belum diketahui',
      );
    }

    if (isInside) {
      return const _Chip(
        icon: Icons.check_circle_rounded,
        label: 'Anda di area ini',
        tone: AppColors.success,
        background: Color(0x1F2E7D5B),
      );
    }

    final away = mosque.metersToEnter;
    return _Chip(
      icon: Icons.directions_walk_rounded,
      label: away == null
          ? 'Di luar area'
          : '${formatDistance(away)} lagi ke area',
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    this.tone = AppColors.textSecondary,
    this.background,
  });

  final IconData icon;
  final String label;
  final Color tone;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tone),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pengganti cincin progres untuk tamu yang belum login: jumlah titik saja,
/// karena kemajuan memang belum ada yang bisa ditampilkan.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'titik',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
