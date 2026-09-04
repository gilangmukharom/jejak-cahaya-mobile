import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'dart:async';

import '../core/config/app_config.dart';
import '../core/di/injection.dart';
import '../core/services/prayer_notification_service.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class JejakCahayaApp extends StatefulWidget {
  const JejakCahayaApp({super.key});

  @override
  State<JejakCahayaApp> createState() => _JejakCahayaAppState();
}

class _JejakCahayaAppState extends State<JejakCahayaApp> {
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

      // Pengingat sholat dipasang di muka untuk tujuh hari. Jendela itu perlu
      // diisi ulang, dan mengisinya di sini berarti ia tetap penuh bagi orang
      // yang membuka aplikasi tetapi tidak pernah menyentuh tab Ibadah.
      // Tidak meminta izin apa pun: bila notifikasinya belum dinyalakan atau
      // belum ada koordinat tersimpan, panggilan ini tidak melakukan apa-apa.
      unawaited(sl<PrayerNotificationService>().refreshFromSavedLocation());
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
        builder: (context, child) {
          // Kunci skala teks pada rentang yang wajar. Kartu koleksi dan panel
          // radar memakai tata letak padat; skala 2× membuat teksnya terpotong.
          final scale = MediaQuery.textScalerOf(context).clamp(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.3,
          );

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scale),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
