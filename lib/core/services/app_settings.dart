import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Setelan Family & Accessibility dari konsep produk: mode keluarga, teks
/// besar, mode hemat baterai, dan opsi tanpa AR.
///
/// Milik perangkat, bukan milik akun — tetap ada meski pemain keluar akun.
/// [ChangeNotifier] supaya setiap layar yang terpengaruh langsung berubah
/// begitu saklarnya digeser, tanpa memulai ulang aplikasi.
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs);

  final SharedPreferences _prefs;

  static const String _largeTextKey = 'nv_large_text';
  static const String _batterySaverKey = 'nv_battery_saver';
  static const String _familyModeKey = 'nv_family_mode';
  static const String _arEnabledKey = 'nv_ar_enabled';

  /// Teks diperbesar di seluruh aplikasi.
  bool get largeText => _prefs.getBool(_largeTextKey) ?? false;

  /// GPS diperbarui lebih jarang dan animasi perayaan dimatikan.
  bool get batterySaver => _prefs.getBool(_batterySaverKey) ?? false;

  /// Pengingat keselamatan untuk anak dan pendampingnya saat memindai dan
  /// saat kamera AR menyala.
  bool get familyMode => _prefs.getBool(_familyModeKey) ?? false;

  /// Bila mati, hero selalu tampil sebagai model 3D yang bisa diputar —
  /// kamera tidak dipakai setelah scan.
  bool get arEnabled => _prefs.getBool(_arEnabledKey) ?? true;

  Future<void> setLargeText({required bool value}) =>
      _set(_largeTextKey, value);
  Future<void> setBatterySaver({required bool value}) =>
      _set(_batterySaverKey, value);
  Future<void> setFamilyMode({required bool value}) =>
      _set(_familyModeKey, value);
  Future<void> setArEnabled({required bool value}) =>
      _set(_arEnabledKey, value);

  Future<void> _set(String key, bool value) async {
    await _prefs.setBool(key, value);
    notifyListeners();
  }
}
