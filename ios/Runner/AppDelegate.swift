import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Tanpa baris ini, pengingat waktu sholat tidak tampil ketika aplikasi
    // sedang dibuka — iOS menahannya dan baru menunjukkannya setelah aplikasi
    // ditutup. Delegasinya dipasang di sini, bukan dari sisi Dart, karena
    // UNUserNotificationCenter hanya menerima satu delegate dan penetapannya
    // harus terjadi sebelum peluncuran selesai.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
