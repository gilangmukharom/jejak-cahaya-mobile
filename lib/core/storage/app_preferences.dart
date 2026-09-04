import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_times.dart';

/// Preferensi non-sensitif. Token TIDAK disimpan di sini — lihat `TokenStorage`.
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const String _onboardingKey = 'jc_onboarding_done';
  static const String _lastMosqueKey = 'jc_last_mosque_id';
  static const String _soundKey = 'jc_sound_enabled';

  // ── Jadwal sholat ─────────────────────────────────────────────
  static const String _prayerNotifyKey = 'jc_prayer_notify';
  static const String _prayerNotifyPrefix = 'jc_prayer_notify_';
  static const String _prayerReminderKey = 'jc_prayer_reminder_min';
  static const String _prayerMethodKey = 'jc_prayer_method';
  static const String _prayerMadhabKey = 'jc_prayer_madhab';
  static const String _prayerLatKey = 'jc_prayer_lat';
  static const String _prayerLonKey = 'jc_prayer_lon';
  static const String _prayerPlaceKey = 'jc_prayer_place';

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

  // ── Jadwal sholat & notifikasi ────────────────────────────────

  /// Saklar induk notifikasi adzan.
  ///
  /// Sengaja dimulai dari mati. Aplikasi ini dipasang untuk bermain, bukan
  /// untuk mengingatkan sholat; menyalakan notifikasi tanpa diminta berarti
  /// mengambil izin yang tidak pernah diberikan dan mengejutkan orang dengan
  /// bunyi pada jam empat pagi.
  bool get prayerNotificationsEnabled =>
      _prefs.getBool(_prayerNotifyKey) ?? false;

  Future<void> setPrayerNotificationsEnabled({required bool enabled}) =>
      _prefs.setBool(_prayerNotifyKey, enabled);

  /// Apakah [prayer] ikut diingatkan ketika saklar induk menyala.
  ///
  /// Bawaannya menyala, sehingga menyalakan saklar induk langsung menghasilkan
  /// jadwal lengkap; pengguna yang hanya ingin sebagian tinggal mematikan yang
  /// tidak diperlukan.
  bool prayerEnabled(Prayer prayer) =>
      _prefs.getBool('$_prayerNotifyPrefix${prayer.key}') ?? true;

  Future<void> setPrayerEnabled(Prayer prayer, {required bool enabled}) =>
      _prefs.setBool('$_prayerNotifyPrefix${prayer.key}', enabled);

  /// Berapa menit sebelum waktunya notifikasi dibunyikan. 0 = tepat waktu.
  int get prayerReminderMinutes => _prefs.getInt(_prayerReminderKey) ?? 0;

  Future<void> setPrayerReminderMinutes(int minutes) =>
      _prefs.setInt(_prayerReminderKey, minutes);

  CalculationMethod get prayerMethod =>
      CalculationMethod.fromKey(_prefs.getString(_prayerMethodKey));

  Future<void> setPrayerMethod(CalculationMethod method) =>
      _prefs.setString(_prayerMethodKey, method.key);

  AsrMadhab get prayerMadhab =>
      AsrMadhab.fromKey(_prefs.getString(_prayerMadhabKey));

  Future<void> setPrayerMadhab(AsrMadhab madhab) =>
      _prefs.setString(_prayerMadhabKey, madhab.key);

  /// Koordinat terakhir yang dipakai menghitung jadwal.
  ///
  /// Disimpan supaya jadwal tetap bisa ditampilkan — dan notifikasi tetap bisa
  /// dijadwalkan ulang — sebelum GPS sempat mengunci posisi, atau ketika izin
  /// lokasi sedang dicabut. Jadwal yang meleset beberapa detik karena memakai
  /// posisi kemarin jauh lebih berguna daripada layar kosong.
  ({double latitude, double longitude, String? place})? get prayerLocation {
    final latitude = _prefs.getDouble(_prayerLatKey);
    final longitude = _prefs.getDouble(_prayerLonKey);
    if (latitude == null || longitude == null) return null;

    return (
      latitude: latitude,
      longitude: longitude,
      place: _prefs.getString(_prayerPlaceKey),
    );
  }

  Future<void> setPrayerLocation({
    required double latitude,
    required double longitude,
    String? place,
  }) async {
    await _prefs.setDouble(_prayerLatKey, latitude);
    await _prefs.setDouble(_prayerLonKey, longitude);
    if (place != null) await _prefs.setString(_prayerPlaceKey, place);
  }

  Future<void> clear() async {
    // Onboarding sengaja dipertahankan: pengguna yang keluar akun tidak perlu
    // menonton ulang perkenalan aplikasi. Begitu pula setelan jadwal sholat —
    // itu milik perangkat dan orang yang memegangnya, bukan milik sesi
    // permainan yang baru saja berakhir.
    await _prefs.remove(_lastMosqueKey);
  }
}
