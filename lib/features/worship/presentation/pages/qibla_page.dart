import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/qibla_service.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/utils/distance.dart';
import '../cubit/qibla_cubit.dart';
import '../widgets/qibla_dial.dart';

/// Kompas kiblat layar penuh.
class QiblaPage extends StatelessWidget {
  const QiblaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<QiblaCubit>(
      create: (_) => QiblaCubit(
        locationService: sl<LocationService>(),
        preferences: sl<AppPreferences>(),
      )..start(),
      child: const _QiblaView(),
    );
  }
}

class _QiblaView extends StatelessWidget {
  const _QiblaView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arah Kiblat')),
      body: BlocBuilder<QiblaCubit, QiblaState>(
        builder: (context, state) {
          if (!state.hasLocation) return _LocationMissingView(state: state);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _AlignmentBanner(state: state),
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: QiblaDial(
                    headingDeg: state.heading ?? 0,
                    qiblaBearingDeg: state.qiblaBearing!,
                    isAligned: state.isAligned,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _FactsCard(state: state),
              const SizedBox(height: 16),
              if (!state.hasCompass) const _NoCompassNote(),
              if (state.hasCompass && !state.accuracy.isUsable)
                _CalibrationNote(accuracy: state.accuracy),
              const SizedBox(height: 16),
              const _TrueNorthNote(),
            ],
          );
        },
      ),
    );
  }
}

/// Pita di atas piringan: sudah menghadap kiblat atau harus memutar ke mana.
class _AlignmentBanner extends StatelessWidget {
  const _AlignmentBanner({required this.state});

  final QiblaState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offset = state.offsetFromQibla;

    if (offset == null) {
      return _Banner(
        color: AppColors.textMuted,
        icon: Icons.explore_outlined,
        title: 'Kompas belum siap',
        message: state.hasCompass
            ? 'Menunggu bacaan sensor…'
            : 'Perangkat ini tidak memiliki sensor kompas.',
      );
    }

    if (state.isAligned) {
      return const _Banner(
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
        title: 'Anda menghadap kiblat',
        message: 'Penanda emas berada tepat di puncak piringan.',
      );
    }

    // Arah putar disebut dengan kata, bukan hanya tanda derajat. Orang yang
    // sedang memegang ponsel di atas sajadah tidak sedang membaca tanda plus
    // dan minus.
    final turn = offset > 0 ? 'kanan' : 'kiri';

    return _Banner(
      color: AppColors.primary,
      icon: offset > 0 ? Icons.turn_right_rounded : Icons.turn_left_rounded,
      title: 'Putar ${offset.abs().round()}° ke $turn',
      message: 'Sampai penanda emas berada di puncak piringan.',
      titleStyle: theme.textTheme.titleMedium,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
    this.titleStyle,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String message;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: (titleStyle ?? theme.textTheme.titleMedium)?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Angka-angka yang tetap berguna meski kompasnya tidak bisa dipakai.
class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.state});

  final QiblaState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      child: Column(
        children: [
          _Fact(
            label: 'Sudut kiblat',
            value: '${state.qiblaBearing!.toStringAsFixed(1)}° dari utara',
          ),
          const Divider(height: 20, color: AppColors.surfaceMuted),
          _Fact(
            label: 'Arah hadap perangkat',
            value: state.heading == null ? '—' : '${state.heading!.round()}°',
          ),
          const Divider(height: 20, color: AppColors.surfaceMuted),
          _Fact(
            label: 'Jarak ke Ka\'bah',
            value: formatDistance(state.distanceToKaabaM!),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _NoCompassNote extends StatelessWidget {
  const _NoCompassNote();

  @override
  Widget build(BuildContext context) {
    return const _Note(
      icon: Icons.sensors_off_rounded,
      text: 'Perangkat ini tidak melaporkan sensor magnet, jadi piringan tidak '
          'bisa berputar mengikuti arah hadap. Sudut kiblat di atas tetap benar '
          '— pakai kompas biasa dan putar sebanyak sudut tersebut dari utara.',
    );
  }
}

class _CalibrationNote extends StatelessWidget {
  const _CalibrationNote({required this.accuracy});

  final CompassAccuracy accuracy;

  @override
  Widget build(BuildContext context) {
    return _Note(
      icon: Icons.refresh_rounded,
      color: AppColors.warning,
      text: accuracy == CompassAccuracy.interference
          ? 'Ada gangguan magnet di sekitar perangkat — biasanya casing '
              'bermagnet, speaker, atau rangka logam. Jauhkan lalu coba lagi.'
          : 'Kompas perlu dikalibrasi. Gerakkan perangkat membentuk angka 8 '
              'beberapa kali.',
    );
  }
}

class _TrueNorthNote extends StatelessWidget {
  const _TrueNorthNote();

  @override
  Widget build(BuildContext context) {
    return const _Note(
      icon: Icons.info_outline_rounded,
      text: 'Piringan mengikuti utara magnet. Di Indonesia selisihnya terhadap '
          'utara sejati di bawah 1,5° — jauh lebih kecil daripada ketelitian '
          'sensor kompas ponsel itu sendiri.',
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? AppColors.textMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: tint),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style:
                theme.textTheme.labelSmall?.copyWith(color: tint, height: 1.5),
          ),
        ),
      ],
    );
  }
}

/// Koordinat belum diketahui — sudut kiblat tidak bisa dihitung sama sekali.
class _LocationMissingView extends StatelessWidget {
  const _LocationMissingView({required this.state});

  final QiblaState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.explore_off_outlined,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: 20),
            Text(
              'Lokasi diperlukan',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Arah kiblat dihitung dari posisi Anda ke Ka\'bah, jadi '
              'koordinatnya harus diketahui lebih dulu.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: state.isLocating
                  ? null
                  : () => context.read<QiblaCubit>().refreshLocation(),
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: Text(state.isLocating ? 'Mencari…' : 'Cari lokasi saya'),
            ),
          ],
        ),
      ),
    );
  }
}
