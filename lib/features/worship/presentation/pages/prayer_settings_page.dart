import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/prayer_times.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/prayer_notification_service.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/utils/id_date.dart';
import '../cubit/prayer_times_cubit.dart';

/// Setelan jadwal sholat: notifikasi per waktu, jeda pengingat, dan metode
/// perhitungan.
///
/// Dipisahkan dari tab Ibadah karena isinya dibuka sekali lalu ditinggalkan.
/// Yang dipakai setiap hari — saklar induk dan lonceng per waktu — tetap ada di
/// tab utamanya; halaman ini untuk hal-hal yang diputuskan sekali seumur
/// pemasangan.
class PrayerSettingsPage extends StatelessWidget {
  const PrayerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PrayerTimesCubit>(
      create: (_) => PrayerTimesCubit(
        locationService: sl<LocationService>(),
        preferences: sl<AppPreferences>(),
        notifications: sl<PrayerNotificationService>(),
      )..load(),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Jadwal')),
      body: BlocBuilder<PrayerTimesCubit, PrayerTimesState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _MasterSwitch(state: state),
              const SizedBox(height: 8),
              _PerPrayerSection(state: state),
              const SizedBox(height: 20),
              _ReminderSection(state: state),
              const SizedBox(height: 20),
              _MethodSection(state: state),
              const SizedBox(height: 20),
              _MadhabSection(state: state),
              const SizedBox(height: 24),
              _ScheduleStatus(state: state),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _MasterSwitch extends StatelessWidget {
  const _MasterSwitch({required this.state});

  final PrayerTimesState state;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: SwitchListTile(
        value: state.notificationsEnabled,
        onChanged: (value) => _toggle(context, enabled: value),
        title: const Text('Notifikasi waktu sholat'),
        subtitle: Text(
          state.permission == NotificationPermission.grantedInexact
              ? 'Aktif, tetapi sistem membatasi ketepatannya beberapa menit'
              : 'Pengingat dipasang lewat alarm sistem, tanpa koneksi internet',
        ),
        secondary: const Icon(Icons.notifications_active_rounded),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, {required bool enabled}) async {
    final messenger = ScaffoldMessenger.of(context);
    final permission = await context
        .read<PrayerTimesCubit>()
        .setNotificationsEnabled(enabled: enabled);

    switch (permission) {
      case NotificationPermission.denied:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Izin notifikasi ditolak. Aktifkan lewat Pengaturan sistem.',
            ),
          ),
        );
      case NotificationPermission.grantedInexact:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Pengingat aktif. Izin alarm presisi belum diberikan, jadi '
              'waktunya bisa meleset beberapa menit.',
            ),
          ),
        );
      case NotificationPermission.granted || null:
        break;
    }
  }
}

/// Lima lonceng, satu per waktu sholat wajib.
class _PerPrayerSection extends StatelessWidget {
  const _PerPrayerSection({required this.state});

  final PrayerTimesState state;

  @override
  Widget build(BuildContext context) {
    final enabled = state.notificationsEnabled;

    return Opacity(
      // Diredupkan, bukan disembunyikan. Menyembunyikannya membuat orang yang
      // baru menyalakan saklar induk mengira tidak ada yang bisa diatur lagi.
      opacity: enabled ? 1 : 0.45,
      child: _Card(
        child: Column(
          children: [
            for (final prayer in Prayer.notifiable)
              SwitchListTile(
                value: state.enabledPrayers.contains(prayer),
                onChanged: enabled
                    ? (value) => context
                        .read<PrayerTimesCubit>()
                        .setPrayerEnabled(prayer, enabled: value)
                    : null,
                dense: true,
                title: Text(prayer.label),
                subtitle: state.today == null
                    ? null
                    : Text('Hari ini ${formatClock(state.today![prayer])}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReminderSection extends StatelessWidget {
  const _ReminderSection({required this.state});

  final PrayerTimesState state;

  /// Pilihan jeda. Dibatasi lima nilai, bukan dibuat bebas: selisih dua menit
  /// tidak berarti apa-apa bagi orang yang perlu bersiap, dan daftar pendek
  /// bisa dipilih dengan satu ketukan.
  static const List<int> _choices = [0, 5, 10, 15, 30];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          'Waktu pengingat',
          subtitle: 'Kapan notifikasi dibunyikan, relatif terhadap adzan.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final minutes in _choices)
              ChoiceChip(
                selected: state.reminderMinutes == minutes,
                onSelected: (_) => context
                    .read<PrayerTimesCubit>()
                    .setReminderMinutes(minutes),
                label: Text(
                  minutes == 0 ? 'Tepat waktu' : '$minutes menit sebelum',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MethodSection extends StatelessWidget {
  const _MethodSection({required this.state});

  final PrayerTimesState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          'Metode perhitungan',
          subtitle: 'Menentukan sudut matahari untuk Subuh dan Isya.',
        ),
        _Card(
          child: RadioGroup<String>(
            groupValue: state.method.key,
            onChanged: (key) {
              if (key == null) return;
              context
                  .read<PrayerTimesCubit>()
                  .setMethod(CalculationMethod.fromKey(key));
            },
            child: Column(
              children: [
                for (final method in CalculationMethod.all)
                  RadioListTile<String>(
                    value: method.key,
                    dense: true,
                    title: Text(method.label),
                    subtitle: Text(method.description),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MadhabSection extends StatelessWidget {
  const _MadhabSection({required this.state});

  final PrayerTimesState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          'Mazhab waktu Ashar',
          subtitle: 'Panjang bayangan yang menandai masuknya Ashar.',
        ),
        _Card(
          child: RadioGroup<String>(
            groupValue: state.madhab.key,
            onChanged: (key) {
              if (key == null) return;
              context
                  .read<PrayerTimesCubit>()
                  .setMadhab(AsrMadhab.fromKey(key));
            },
            child: Column(
              children: [
                for (final madhab in AsrMadhab.values)
                  RadioListTile<String>(
                    value: madhab.key,
                    dense: true,
                    title: Text(madhab.label),
                    subtitle: Text(
                      'Bayangan ${madhab.shadowFactor}× tinggi benda',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bukti bahwa jadwalnya benar-benar terpasang di sistem.
class _ScheduleStatus extends StatelessWidget {
  const _ScheduleStatus({required this.state});

  final PrayerTimesState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final message = state.notificationsEnabled
        ? '${state.scheduledCount} pengingat terpasang untuk tujuh hari ke '
            'depan. Daftarnya diisi ulang setiap kali tab Ibadah dibuka.'
        : 'Tidak ada pengingat yang terpasang.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.event_available_outlined,
            size: 16, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: AppColors.textMuted, height: 1.5),
          ),
        ),
      ],
    );
  }
}
