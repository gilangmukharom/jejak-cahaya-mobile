import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/app_settings.dart';
import '../../../../core/services/location_service.dart';

/// Pengaturan "Family & Accessibility" dari konsep produk.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = sl<AppSettings>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Pengaturan & Aksesibilitas')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _GroupTitle('Keluarga & keselamatan'),
            _SettingTile(
              icon: Icons.family_restroom_rounded,
              title: 'Mode Keluarga',
              subtitle:
                  'Pengingat keselamatan saat memindai dan saat kamera AR menyala: '
                  'bermain bersama pendamping, perhatikan jalan, jangan masuki area terlarang.',
              value: settings.familyMode,
              onChanged: (value) => settings.setFamilyMode(value: value),
            ),
            const SizedBox(height: 18),
            const _GroupTitle('Tampilan & suara'),
            _SettingTile(
              icon: Icons.text_increase_rounded,
              title: 'Teks besar',
              subtitle:
                  'Perbesar seluruh teks di aplikasi agar lebih mudah dibaca.',
              value: settings.largeText,
              onChanged: (value) => settings.setLargeText(value: value),
            ),
            const _InfoTile(
              icon: Icons.volume_up_rounded,
              title: 'Audio narasi',
              subtitle:
                  'Ketuk "Dengarkan kisah" pada lembar penjelasan atau kisah lengkap hero '
                  'untuk mendengarkannya dibacakan dalam bahasa Indonesia.',
            ),
            const SizedBox(height: 18),
            const _GroupTitle('Kamera & baterai'),
            _SettingTile(
              icon: Icons.view_in_ar_rounded,
              title: 'Tampilkan hero dengan AR',
              subtitle: settings.arEnabled
                  ? 'Hero hadir lewat kamera setelah QR dipindai.'
                  : 'Mati: hero selalu tampil sebagai model 3D yang bisa diputar, tanpa kamera.',
              value: settings.arEnabled,
              onChanged: (value) => settings.setArEnabled(value: value),
            ),
            _SettingTile(
              icon: Icons.battery_saver_rounded,
              title: 'Mode hemat baterai',
              subtitle:
                  'GPS di peta diperbarui lebih jarang dan animasi perayaan dimatikan. '
                  'Pemindaian QR tetap memakai lokasi yang akurat.',
              value: settings.batterySaver,
              onChanged: (value) async {
                await settings.setBatterySaver(value: value);
                // Aliran GPS yang sedang berjalan memakai setelan lama.
                await sl<LocationService>().restartTracking();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        activeThumbColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(
      {required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}
