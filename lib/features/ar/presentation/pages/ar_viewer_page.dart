import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/collectible.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../game/data/game_repository.dart';
import '../widgets/ar_experience.dart';

/// Melihat lagi tokoh yang sudah ditemukan dalam AR, dibuka dari koleksi.
///
/// Collectible diambil ulang dari server alih-alih dititipkan lewat rute:
/// backend hanya mengirim `modelUrl` untuk tokoh yang sudah ditemukan, dan
/// pemeriksaan itu tidak boleh bisa dilewati dengan menyusun tautan sendiri.
class ArViewerPage extends StatefulWidget {
  const ArViewerPage({required this.idOrSlug, super.key});

  final String idOrSlug;

  @override
  State<ArViewerPage> createState() => _ArViewerPageState();
}

class _ArViewerPageState extends State<ArViewerPage> {
  Collectible? _collectible;
  Failure? _failure;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });

    try {
      final collectible =
          await sl<GameRepository>().fetchCollectible(widget.idOrSlug);
      if (!mounted) return;
      setState(() {
        _collectible = collectible;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = FailureMapper.map(error);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingView(message: 'Memanggil tokoh…'));
    }

    final failure = _failure;
    if (failure != null) {
      return Scaffold(
        appBar: AppBar(),
        body: FailureView(failure: failure, onRetry: _load),
      );
    }

    final collectible = _collectible!;
    if (!collectible.isDiscovered || !collectible.hasArModel) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(
          icon: Icons.view_in_ar_rounded,
          title: 'Belum bisa dilihat dalam AR',
          message:
              'Temukan hero ini di lokasi bersejarahnya untuk menghadirkannya di sekitarmu.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: ArExperience(
        collectible: collectible,
        onBack: () => context.pop(),
      ),
    );
  }
}
