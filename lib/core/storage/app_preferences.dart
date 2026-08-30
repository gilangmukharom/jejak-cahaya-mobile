import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi non-sensitif. Token TIDAK disimpan di sini — lihat `TokenStorage`.
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const String _onboardingKey = 'jc_onboarding_done';
  static const String _lastMosqueKey = 'jc_last_mosque_id';
  static const String _soundKey = 'jc_sound_enabled';

  bool get hasSeenOnboarding => _prefs.getBool(_onboardingKey) ?? false;
  Future<void> setOnboardingSeen() => _prefs.setBool(_onboardingKey, true);

  /// Masjid terakhir yang dipilih, agar aplikasi langsung membuka peta yang
  /// relevan alih-alih meminta pemain memilih ulang setiap kali dibuka.
  String? get lastMosqueId => _prefs.getString(_lastMosqueKey);
  Future<void> setLastMosqueId(String id) =>
      _prefs.setString(_lastMosqueKey, id);

  bool get soundEnabled => _prefs.getBool(_soundKey) ?? true;
  Future<void> setSoundEnabled({required bool enabled}) =>
      _prefs.setBool(_soundKey, enabled);

  Future<void> clear() async {
    // Onboarding sengaja dipertahankan: pengguna yang keluar akun tidak perlu
    // menonton ulang perkenalan aplikasi.
    await _prefs.remove(_lastMosqueKey);
  }
}
