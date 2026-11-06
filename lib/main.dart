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

  // Peta penjelajahan digambar sampai ke tepi layar, termasuk di belakang bilah
  // status dan bilah navigasi sistem. Tanpa mode ini keduanya tetap menjadi
  // balok legam yang memotong peta, dan layar utama berhenti terasa seperti
  // permainan.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Ikonnya dibuat gelap: latar di belakangnya adalah peta terang, dan ikon
  // terang bawaan akan lenyap di atasnya.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await configureDependencies();

  runApp(const JejakCahayaApp());
}
