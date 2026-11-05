import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/config/app_config.dart';
import '../core/di/injection.dart';
import '../core/services/app_settings.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class NusaverseApp extends StatefulWidget {
  const NusaverseApp({super.key});

  @override
  State<NusaverseApp> createState() => _NusaverseAppState();
}

class _NusaverseAppState extends State<NusaverseApp> {
  late final AuthCubit _authCubit;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();

    _authCubit = sl<AuthCubit>();
    _appRouter = AppRouter(_authCubit);

    // Dijalankan setelah frame pertama agar splash sempat tergambar sebelum
    // permintaan jaringan dimulai.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authCubit.restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>.value(
      value: _authCubit,
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _appRouter.router,
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => ListenableBuilder(
          listenable: sl<AppSettings>(),
          builder: (context, _) {
            // Kunci skala teks pada rentang yang wajar. Kartu koleksi dan panel
            // radar memakai tata letak padat; skala 2× membuat teksnya
            // terpotong. Mode teks besar menaikkan batas bawahnya ke 1,3× —
            // terbaca jelas tanpa merusak tata letak.
            final largeText = sl<AppSettings>().largeText;
            final scale = MediaQuery.textScalerOf(context).clamp(
              minScaleFactor: largeText ? 1.3 : 0.9,
              maxScaleFactor: largeText ? 1.45 : 1.3,
            );

            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scale),
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}
