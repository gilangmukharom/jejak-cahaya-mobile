import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/mosque.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../game/presentation/cubit/geofence_cubit.dart';
import '../widgets/location_card.dart';

/// Daftar seluruh lokasi permainan, terurut dari yang terdekat.
///
/// Layar ini menjawab pertanyaan yang tidak pernah punya tempat sebelumnya:
/// permainan berjalan di mana saja, dan sudah sejauh apa saya di masing-masing.
/// Sebelumnya aplikasi hanya mengenal satu masjid, sehingga "lokasi" bukan
/// sesuatu yang bisa dipilih — hanya sesuatu yang harus didatangi.
///
/// Memakai ulang [GeofenceCubit] alih-alih cubit sendiri. Cubit itu sudah
/// memegang daftar masjid, posisi pemain, dan lokasi mana yang sedang dibuka;
/// membuat sumber kedua berarti dua layar bisa menampilkan jawaban berbeda atas
/// pertanyaan "saya sedang main di mana" — dan yang salah selalu terlihat lebih
/// meyakinkan karena ia yang paling baru digambar.
class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key});

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage> {
  late final GeofenceCubit _cubit = sl<GeofenceCubit>();

  @override
  void initState() {
    super.initState();

    // Angka kemajuan berubah setiap kali pemain memindai sesuatu, dan layar ini
    // bisa dibuka berjam-jam setelah itu. Disegarkan saat dibuka, bukan hanya
    // saat ditarik ke bawah.
    _cubit.refreshMosques();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GeofenceCubit>.value(
      value: _cubit,
      child: const _LocationsView(),
    );
  }
}

class _LocationsView extends StatelessWidget {
  const _LocationsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: BlocBuilder<GeofenceCubit, GeofenceState>(
        builder: (context, state) {
          final mosques = _sorted(state);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => context.read<GeofenceCubit>().refreshMosques(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _Header(state: state),
                if (mosques.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      icon: Icons.mosque_outlined,
                      title: 'Belum ada lokasi',
                      message:
                          'Pengurus belum menyiapkan lokasi penjelajahan mana pun. '
                          'Coba lagi nanti.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    sliver: SliverList.separated(
                      itemCount: mosques.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final mosque = mosques[index];

                        return LocationCard(
                          // Kunci berbasis id, bukan posisi. Daftar diurut
                          // ulang setiap kali pemain bergerak, dan tanpa ini
                          // animasi masuk tiap kartu ikut berpindah ke kartu
                          // lain — cincin progres akan menganimasikan angka
                          // milik masjid yang berbeda.
                          key: ValueKey(mosque.id),
                          mosque: mosque,
                          index: index,
                          isActive: state.mosque?.id == mosque.id,
                          onTap: () =>
                              context.push(AppRoutes.locationDetail(mosque.id)),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Terdekat lebih dulu.
  ///
  /// Server sudah mengurutkannya, tetapi jarak dihitung ulang di perangkat pada
  /// setiap pembaruan GPS — jadi tanpa pengurutan di sini daftar akan
  /// mempertahankan urutan dari beberapa menit yang lalu sementara angkanya
  /// sudah berubah, dan kartu paling atas berhenti menjadi yang paling dekat.
  List<Mosque> _sorted(GeofenceState state) {
    final position = state.position;
    if (position == null) return state.mosques;

    final withDistance = state.mosques
        .map(
          (mosque) => mosque.withDistance(
            LocationService.distanceMeters(
              fromLat: position.latitude,
              fromLon: position.longitude,
              toLat: mosque.latitude,
              toLon: mosque.longitude,
            ),
          ),
        )
        .toList();

    withDistance.sort(
      (a, b) => (a.distanceM ?? double.infinity)
          .compareTo(b.distanceM ?? double.infinity),
    );
    return withDistance;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final GeofenceState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inside = state.mosques.where((m) => m.isInside == true).length;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 168,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnDark,
      title: const Text('Lokasi Penjelajahan'),
      flexibleSpace: FlexibleSpaceBar(
        background: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.mosques.isEmpty
                        ? 'Memuat lokasi…'
                        : '${state.mosques.length} lokasi tersedia',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    inside > 0
                        ? 'Anda sedang berada di area salah satunya — permainan terbuka.'
                        : 'Datangi salah satunya untuk membuka peta penjelajahan di sana.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textOnDark.withValues(alpha: 0.72),
                      height: 1.5,
                    ),
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
