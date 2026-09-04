import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/prayer_times.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/prayer_notification_service.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/utils/distance.dart';
import '../../../../core/utils/id_date.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../game/presentation/pages/home_shell.dart';
import '../cubit/prayer_times_cubit.dart';
import '../cubit/qibla_cubit.dart';
import '../widgets/qibla_dial.dart';

/// Tab Ibadah: jadwal sholat hari ini dan arah kiblat.
///
/// Satu-satunya layar utama aplikasi yang tidak menyentuh server sama sekali,
/// dan satu-satunya yang tetap lengkap ketika pemain berada jauh dari masjid
/// mana pun. Itu bukan kebetulan — layar inilah yang membuat penguncian area
/// permainan tidak lagi berarti aplikasinya tertutup.
class WorshipPage extends StatelessWidget {
  const WorshipPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PrayerTimesCubit>(
          create: (_) => PrayerTimesCubit(
            locationService: sl<LocationService>(),
            preferences: sl<AppPreferences>(),
            notifications: sl<PrayerNotificationService>(),
          )..load(),
        ),
        BlocProvider<QiblaCubit>(
          create: (_) => QiblaCubit(
            locationService: sl<LocationService>(),
            preferences: sl<AppPreferences>(),
          )..start(),
        ),
      ],
      child: const _WorshipView(),
    );
  }
}

class _WorshipView extends StatelessWidget {
  const _WorshipView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ibadah'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.prayerSettings),
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Pengaturan jadwal',
          ),
        ],
      ),
      body: BlocBuilder<PrayerTimesCubit, PrayerTimesState>(
        builder: (context, state) {
          if (!state.hasSchedule) return const LoadingView();

          final schedule = state.today!;

          return RefreshIndicator(
            onRefresh: () => context.read<PrayerTimesCubit>().refreshLocation(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                HomeShell.reservedBottom(context) + 16,
              ),
              children: [
                _NextPrayerCard(state: state),
                const SizedBox(height: 14),
                _LocationBanner(state: state),
                const SizedBox(height: 14),
                _ScheduleCard(schedule: schedule, state: state),
                const SizedBox(height: 14),
                const _QiblaCard(),
                const SizedBox(height: 14),
                _MethodFootnote(state: state),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Kartu utama: sholat berikutnya dan berapa lama lagi.
class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard({required this.state});

  final PrayerTimesState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = state.next;
    final remaining = state.untilNext;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatLongDate(state.today!.date),
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textOnDark.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 14),
          if (next == null)
            Text(
              'Jadwal hari ini sudah lengkap',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w800,
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Menuju ${next.$1.label}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatClock(next.$2),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: AppColors.textOnDark,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (remaining != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        formatCountdown(remaining),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.textOnDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _NotificationSwitchRow(state: state),
        ],
      ),
    );
  }
}

/// Saklar induk notifikasi, diletakkan di kartu utama.
///
/// Ditaruh di sini alih-alih hanya di halaman pengaturan karena inilah
/// keputusan yang paling mungkin ingin diubah seseorang sesudah melihat
/// jadwalnya — dan menyembunyikannya di balik satu ketukan lagi berarti
/// kebanyakan orang tidak akan pernah menemukannya.
class _NotificationSwitchRow extends StatelessWidget {
  const _NotificationSwitchRow({required this.state});

  final PrayerTimesState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = state.notificationsEnabled;

    final subtitle = switch ((enabled, state.permission)) {
      (false, _) => 'Aplikasi tidak akan mengingatkan waktu sholat',
      (true, NotificationPermission.grantedInexact) =>
        'Aktif — sistem membatasi ketepatannya beberapa menit',
      (true, _) when state.enabledPrayers.isEmpty =>
        'Aktif, tetapi belum ada waktu yang dipilih',
      (true, _) => 'Aktif untuk ${state.enabledPrayers.length} waktu sholat',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(
            enabled
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_outlined,
            size: 20,
            color: enabled ? AppColors.gold : AppColors.textOnDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Notifikasi adzan',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.textOnDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: AppColors.gold,
            onChanged: (value) => _toggle(context, enabled: value),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, {required bool enabled}) async {
    final messenger = ScaffoldMessenger.of(context);
    final permission = await context
        .read<PrayerTimesCubit>()
        .setNotificationsEnabled(enabled: enabled);

    if (permission == NotificationPermission.denied) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Izin notifikasi ditolak. Aktifkan lewat Pengaturan sistem '
            'agar pengingat bisa muncul.',
          ),
        ),
      );
    }
  }
}

/// Dari mana koordinat jadwal ini berasal.
class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.state});

  final PrayerTimesState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, message) = switch (state.source) {
      PrayerLocationSource.live => (
          Icons.my_location_rounded,
          'Dihitung dari lokasi Anda saat ini'
        ),
      PrayerLocationSource.saved => (
          Icons.history_rounded,
          'Dihitung dari lokasi terakhir yang tersimpan'
        ),
      PrayerLocationSource.fallback => (
          Icons.warning_amber_rounded,
          'Lokasi belum diketahui — jadwal memakai patokan Jakarta'
        ),
    };

    final coordinate = state.latitude == null
        ? null
        : '${state.latitude!.toStringAsFixed(4)}, '
            '${state.longitude!.toStringAsFixed(4)}';

    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              if (coordinate != null)
                Text(
                  coordinate,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: state.isLoading
              ? null
              : () => context.read<PrayerTimesCubit>().refreshLocation(),
          child: Text(state.isLoading ? 'Memuat…' : 'Perbarui'),
        ),
      ],
    );
  }
}

/// Daftar tujuh waktu, dengan lonceng pada lima yang bisa diingatkan.
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule, required this.state});

  final DailyPrayerTimes schedule;
  final PrayerTimesState state;

  @override
  Widget build(BuildContext context) {
    final current = state.current?.$1;
    final next = state.next?.$1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      child: Column(
        children: [
          for (final prayer in Prayer.values)
            _PrayerRow(
              prayer: prayer,
              time: schedule[prayer],
              isCurrent: prayer == current,
              isNext: prayer == next,
              isLast: prayer == Prayer.values.last,
              notificationsEnabled: state.notificationsEnabled,
              isNotified: state.enabledPrayers.contains(prayer),
            ),
        ],
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.prayer,
    required this.time,
    required this.isCurrent,
    required this.isNext,
    required this.isLast,
    required this.notificationsEnabled,
    required this.isNotified,
  });

  final Prayer prayer;
  final DateTime time;
  final bool isCurrent;
  final bool isNext;
  final bool isLast;
  final bool notificationsEnabled;
  final bool isNotified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Penanda hanya diberikan kepada waktu yang sedang berjalan dan waktu
    // berikutnya. Mewarnai lebih banyak dari itu membuat keduanya kehilangan
    // arti — dan justru dua itulah yang dicari orang saat membuka jadwal.
    final highlight = isNext
        ? AppColors.primary
        : isCurrent
            ? AppColors.success
            : null;

    return Container(
      decoration: BoxDecoration(
        color: isNext ? AppColors.primary.withValues(alpha: 0.05) : null,
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.surfaceMuted),
              ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          SizedBox(
            width: 4,
            height: 26,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: highlight ?? Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  prayer.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                    color: highlight ?? AppColors.textPrimary,
                  ),
                ),
                if (isCurrent || isNext)
                  Text(
                    isNext ? 'Berikutnya' : 'Sedang berlangsung',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: highlight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formatClock(time),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: highlight ?? AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(
            width: 48,
            child: prayer.isObligatory
                ? IconButton(
                    onPressed: notificationsEnabled
                        ? () =>
                            context.read<PrayerTimesCubit>().setPrayerEnabled(
                                  prayer,
                                  enabled: !isNotified,
                                )
                        : null,
                    tooltip: isNotified
                        ? 'Matikan pengingat ${prayer.label}'
                        : 'Nyalakan pengingat ${prayer.label}',
                    icon: Icon(
                      isNotified
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_outlined,
                      size: 20,
                      color: notificationsEnabled && isNotified
                          ? AppColors.gold
                          : AppColors.textMuted,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// Ringkasan arah kiblat, sekaligus pintu ke kompas layar penuh.
class _QiblaCard extends StatelessWidget {
  const _QiblaCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<QiblaCubit, QiblaState>(
      builder: (context, state) {
        final bearing = state.qiblaBearing;

        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => context.push(AppRoutes.qibla),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceMuted),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: QiblaDial(
                      headingDeg: state.heading ?? 0,
                      qiblaBearingDeg: bearing ?? 0,
                      isAligned: state.isAligned,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Arah Kiblat',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bearing == null
                              ? 'Menunggu lokasi…'
                              : '${bearing.toStringAsFixed(1)}° dari utara',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        if (state.distanceToKaabaM != null)
                          Text(
                            '${formatDistance(state.distanceToKaabaM!)} ke Ka\'bah',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MethodFootnote extends StatelessWidget {
  const _MethodFootnote({required this.state});

  final PrayerTimesState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.calculate_outlined,
            size: 15, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Metode ${state.method.label} · Ashar mazhab ${state.madhab.label}. '
            'Dihitung di perangkat, tanpa koneksi internet.',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: AppColors.textMuted, height: 1.4),
          ),
        ),
      ],
    );
  }
}
