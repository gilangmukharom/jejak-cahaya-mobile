import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Aplikasi ini dipakai sambil berjalan dan memindai QR dengan satu tangan;
  // rotasi tidak menambah apa pun dan hanya mengacaukan bidik kamera.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await configureDependencies();

  runApp(const JejakCahayaApp());
}
