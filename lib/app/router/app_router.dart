import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/services/scan_result_holder.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/collection/presentation/pages/collection_page.dart';
import '../../features/game/presentation/pages/collectible_detail_page.dart';
import '../../features/game/presentation/pages/discovery_result_page.dart';
import '../../features/game/presentation/pages/explore_page.dart';
import '../../features/game/presentation/pages/geofence_gate_page.dart';
import '../../features/game/presentation/pages/home_shell.dart';
import '../../features/leaderboard/presentation/pages/leaderboard_page.dart';
import '../../features/mission/presentation/pages/mission_detail_page.dart';
import '../../features/mission/presentation/pages/missions_page.dart';
import '../../features/profile/presentation/pages/achievements_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/quiz/presentation/pages/quiz_page.dart';
import '../../features/scanner/presentation/pages/scanner_page.dart';
import 'app_routes.dart';

/// Merakit rute aplikasi.
///
/// Pengalihan berbasis autentikasi ditangani terpusat di [_redirect], bukan di
/// masing-masing layar. Dengan begitu tidak ada halaman yang bisa lupa memeriksa
/// sesi, dan berakhirnya sesi di tengah permainan langsung memindahkan pengguna
/// ke layar masuk dari mana pun mereka berada.
class AppRouter {
  AppRouter(this._authCubit);

  final AuthCubit _authCubit;

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: _CubitRefreshStream(_authCubit.stream),
    redirect: _redirect,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.gate,
        builder: (context, state) => const GeofenceGatePage(),
      ),

      // Cangkang dengan navigasi bawah. StatefulShellRoute mempertahankan
      // state tiap tab, sehingga berpindah dari peta ke koleksi dan kembali
      // tidak memuat ulang peta — penting karena peta menunggu sinyal GPS.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.explore,
                builder: (context, state) => const ExplorePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.collection,
                builder: (context, state) => const CollectionPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.missions,
                builder: (context, state) => const MissionsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // Layar penuh di luar cangkang.
      GoRoute(
        path: AppRoutes.scanner,
        builder: (context, state) => const ScannerPage(),
      ),
      GoRoute(
        path: AppRoutes.discoveryResult,
        builder: (context, state) {
          // Dibaca dari holder, bukan dari `state.extra`. `extra` tidak selalu
          // terbawa saat router menyegarkan diri (mis. karena AuthCubit
          // memancarkan state baru setelah XP bertambah), dan ketika itu
          // terjadi layar penemuan tergantikan sendiri sebelum pemain sempat
          // membacanya.
          final result = sl<ScanResultHolder>().lastResult;
          if (result == null) {
            // Hanya terjadi bila rute dibuka tanpa pernah ada scan, mis. lewat
            // tautan dalam. Kembalikan pemain ke peta alih-alih layar kosong.
            return const ExplorePage();
          }
          return DiscoveryResultPage(result: result);
        },
      ),
      GoRoute(
        path: AppRoutes.collectibleDetailPattern,
        builder: (context, state) => CollectibleDetailPage(
          idOrSlug: state.pathParameters['idOrSlug'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.missionDetailPattern,
        builder: (context, state) => MissionDetailPage(
          missionId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.quizByCollectiblePattern,
        builder: (context, state) => QuizPage(
          collectibleId: state.pathParameters['collectibleId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.quizPattern,
        builder: (context, state) => QuizPage(
          quizId: state.pathParameters['quizId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.leaderboard,
        builder: (context, state) => const LeaderboardPage(),
      ),
      GoRoute(
        path: AppRoutes.achievements,
        builder: (context, state) => const AchievementsPage(),
      ),
    ],
    errorBuilder: (context, state) =>
        _RouteErrorPage(message: state.error?.message),
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final status = _authCubit.state.status;
    final location = state.matchedLocation;

    final isAuthRoute =
        location == AppRoutes.login || location == AppRoutes.register;

    // Tahan di splash sampai pemulihan sesi selesai, agar tidak ada kedipan
    // layar masuk untuk pengguna yang sebenarnya masih login.
    if (status == AuthStatus.initial || status == AuthStatus.checking) {
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    }

    if (status == AuthStatus.unauthenticated) {
      return isAuthRoute ? null : AppRoutes.login;
    }

    // Sudah terautentikasi: layar masuk dan splash tidak lagi relevan.
    if (isAuthRoute || location == AppRoutes.splash) {
      return AppRoutes.gate;
    }

    return null;
  }
}

/// Menjembatani stream Bloc ke [Listenable] yang dipahami go_router.
class _CubitRefreshStream extends ChangeNotifier {
  _CubitRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

class _RouteErrorPage extends StatelessWidget {
  const _RouteErrorPage({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                'Halaman tidak ditemukan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.gate),
                child: const Text('Kembali ke beranda'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
