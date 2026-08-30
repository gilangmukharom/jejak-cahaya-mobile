import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';

/// Cangkang navigasi bawah yang membungkus keempat tab utama.
///
/// Memakai [StatefulNavigationShell] agar state tiap tab tetap hidup: berpindah
/// dari peta ke koleksi dan kembali tidak memulai ulang pencarian sinyal GPS.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _BottomNavBar(navigationShell: navigationShell),
    );
  }
}

/// Bilah navigasi bawah dengan tombol pindai di tengah.
///
/// Ditulis sendiri, bukan memakai `NavigationBar` + `FloatingActionButton`
/// yang di-`centerDocked`: kombinasi itu hanya bekerja di atas `BottomAppBar`
/// yang punya takik (notch). Di atas `NavigationBar` Material 3, FAB-nya
/// menimpa destinasi di tengah dan **menyerap ketukannya**, sehingga tab
/// Koleksi tidak pernah bisa dibuka.
///
/// Di sini tombol pindai menempati slotnya sendiri di dalam baris, jadi tidak
/// ada satu pun area sentuh yang tumpang tindih.
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const double _barHeight = 68;

  /// Urutan branch pada router: 0 peta, 1 koleksi, 2 misi, 3 profil.
  static const List<_NavItem> _leftItems = [
    _NavItem(
        branch: 0,
        icon: Icons.map_outlined,
        activeIcon: Icons.map_rounded,
        label: 'Peta'),
    _NavItem(
      branch: 1,
      icon: Icons.collections_bookmark_outlined,
      activeIcon: Icons.collections_bookmark_rounded,
      label: 'Koleksi',
    ),
  ];

  static const List<_NavItem> _rightItems = [
    _NavItem(
        branch: 2,
        icon: Icons.flag_outlined,
        activeIcon: Icons.flag_rounded,
        label: 'Misi'),
    _NavItem(
      branch: 3,
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profil',
    ),
  ];

  void _onTap(int branch) {
    navigationShell.goBranch(
      branch,
      // Mengetuk tab yang sedang aktif mengembalikan ke akar cabangnya —
      // perilaku yang sudah diharapkan pengguna dari aplikasi bertab.
      initialLocation: branch == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceMuted)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _barHeight,
          child: Row(
            children: [
              for (final item in _leftItems)
                Expanded(
                  child: _NavButton(
                    item: item,
                    isSelected: navigationShell.currentIndex == item.branch,
                    onTap: () => _onTap(item.branch),
                  ),
                ),
              const Expanded(child: _ScanButton()),
              for (final item in _rightItems)
                Expanded(
                  child: _NavButton(
                    item: item,
                    isSelected: navigationShell.currentIndex == item.branch,
                    onTap: () => _onTap(item.branch),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.branch,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final int branch;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.textMuted;

    return Semantics(
      selected: isSelected,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? item.activeIcon : item.icon,
                size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1,
                color: color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aksi utama permainan: satu-satunya cara memperoleh penemuan, jadi diberi
/// bobot visual paling besar di antara kelima slot.
class _ScanButton extends StatelessWidget {
  const _ScanButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Pindai QR checkpoint',
      child: InkWell(
        onTap: () => context.push(AppRoutes.scanner),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                size: 25,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Pindai',
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                height: 1,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
