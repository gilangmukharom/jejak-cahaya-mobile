import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/safe_emit.dart';
import '../../../../core/models/prayer_times.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/prayer_notification_service.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../../../core/storage/app_preferences.dart';

/// Dari mana koordinat yang dipakai menghitung jadwal berasal.
///
/// Perlu dibedakan karena ketiganya menuntut kalimat yang berbeda di layar:
/// posisi terkini tidak perlu dijelaskan, posisi tersimpan perlu diberi tahu
/// bahwa ia mungkin sudah usang, dan posisi cadangan harus jujur mengatakan
/// bahwa jadwalnya belum tentu untuk kota tempat pengguna berada.
enum PrayerLocationSource {
  live,
  saved,
  fallback,
}

class PrayerTimesState extends Equatable {
  const PrayerTimesState({
    this.isLoading = false,
    this.today,
    this.tomorrow,
    this.now,
    this.latitude,
    this.longitude,
    this.source = PrayerLocationSource.fallback,
    this.notificationsEnabled = false,
    this.enabledPrayers = const {},
    this.reminderMinutes = 0,
    this.method = CalculationMethod.kemenag,
    this.madhab = AsrMadhab.syafii,
    this.permission,
    this.scheduledCount = 0,
  });

  final bool isLoading;
  final DailyPrayerTimes? today;

  /// Jadwal besok — dipakai ketika Isya hari ini sudah lewat, agar hitung mundur
  /// berlanjut ke Subuh esok alih-alih berhenti kosong sepanjang malam.
  final DailyPrayerTimes? tomorrow;

  /// Denyut jam, diperbarui tiap detik. Disimpan di state supaya hitung mundur
  /// ikut terbangun tanpa layar perlu menyimpan waktunya sendiri.
  final DateTime? now;

  final double? latitude;
  final double? longitude;
  final PrayerLocationSource source;

  final bool notificationsEnabled;
  final Set<Prayer> enabledPrayers;
  final int reminderMinutes;
  final CalculationMethod method;
  final AsrMadhab madhab;

  /// Hasil permintaan izin terakhir. Null berarti belum pernah diminta.
  final NotificationPermission? permission;

  /// Jumlah pengingat yang benar-benar terpasang di sistem.
  final int scheduledCount;

  bool get hasSchedule => today != null;

  /// Waktu sholat berikutnya, melintasi pergantian hari bila perlu.
  (Prayer, DateTime)? get next {
    final reference = now ?? DateTime.now();
    return today?.nextAfter(reference) ??
        tomorrow?.nextAfter(
          DateTime(reference.year, reference.month, reference.day + 1),
        );
  }

  /// Waktu yang sedang berjalan sekarang.
  (Prayer, DateTime)? get current => today?.currentAt(now ?? DateTime.now());

  /// Sisa waktu menuju sholat berikutnya, atau null bila jadwal belum ada.
  Duration? get untilNext {
    final upcoming = next;
    if (upcoming == null) return null;

    final remaining = upcoming.$2.difference(now ?? DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  PrayerTimesState copyWith({
    bool? isLoading,
    DailyPrayerTimes? today,
    DailyPrayerTimes? tomorrow,
    DateTime? now,
    double? latitude,
    double? longitude,
    PrayerLocationSource? source,
    bool? notificationsEnabled,
    Set<Prayer>? enabledPrayers,
    int? reminderMinutes,
    CalculationMethod? method,
    AsrMadhab? madhab,
    NotificationPermission? permission,
    int? scheduledCount,
  }) =>
      PrayerTimesState(
        isLoading: isLoading ?? this.isLoading,
        today: today ?? this.today,
        tomorrow: tomorrow ?? this.tomorrow,
        now: now ?? this.now,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        source: source ?? this.source,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        enabledPrayers: enabledPrayers ?? this.enabledPrayers,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        method: method ?? this.method,
        madhab: madhab ?? this.madhab,
        permission: permission ?? this.permission,
        scheduledCount: scheduledCount ?? this.scheduledCount,
      );

  @override
  List<Object?> get props => [
        isLoading,
        today,
        tomorrow,
        now,
        latitude,
        longitude,
        source,
        notificationsEnabled,
        enabledPrayers,
        reminderMinutes,
        method,
        madhab,
        permission,
        scheduledCount,
      ];
}

/// Menyusun jadwal sholat harian dan mengatur pengingatnya.
///
/// Tidak pernah menghubungi server. Yang dibutuhkannya hanya koordinat, dan
/// koordinat itu dicari berurutan dari yang paling dapat dipercaya: posisi GPS
/// saat ini, lalu posisi terakhir yang tersimpan, lalu — sebagai jalan terakhir
/// — Jakarta. Urutan itu penting supaya layar jadwal tidak pernah kosong, sebab
/// layar kosong adalah satu-satunya keluaran yang benar-benar tidak berguna
/// bagi orang yang sedang mencari tahu jam berapa Maghrib.
class PrayerTimesCubit extends Cubit<PrayerTimesState>
    with SafeEmit<PrayerTimesState> {
  PrayerTimesCubit({
    required LocationService locationService,
    required AppPreferences preferences,
    required PrayerNotificationService notifications,
  })  : _location = locationService,
        _preferences = preferences,
        _notifications = notifications,
        super(const PrayerTimesState());

  final LocationService _location;
  final AppPreferences _preferences;
  final PrayerNotificationService _notifications;

  Timer? _ticker;
  StreamSubscription<PlayerPosition>? _positionSubscription;

  /// Berapa jauh pengguna harus berpindah sebelum jadwalnya dihitung ulang.
  ///
  /// Waktu sholat bergeser sekitar empat menit untuk setiap satu derajat bujur
  /// — kira-kira 110 km. Dua kilometer karena itu jauh di bawah ambang yang
  /// bisa terlihat pada jadwal bersatuan menit, dan justru itulah gunanya:
  /// menghitung ulang pada setiap kedipan GPS berarti menjadwalkan ulang
  /// tiga puluh lima alarm sistem beberapa kali per menit.
  static const double _significantMoveM = 2000;

  /// Posisi cadangan: Masjid Istiqlal, Jakarta.
  ///
  /// Dipilih sebagai titik yang paling mungkin mendekati pengguna aplikasi ini
  /// bila lokasinya tidak diketahui sama sekali. Layar selalu menyatakan
  /// terang-terangan ketika jadwal berasal dari sini.
  static const double _fallbackLatitude = -6.1701;
  static const double _fallbackLongitude = 106.8314;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));

    // Titik awal yang bisa didapat seketika, tanpa menyentuh GPS.
    final (latitude, longitude, source) = _seedLocation();

    emit(
      state.copyWith(
        isLoading: false,
        latitude: latitude,
        longitude: longitude,
        source: source,
        notificationsEnabled: _preferences.prayerNotificationsEnabled,
        enabledPrayers: _readEnabledPrayers(),
        reminderMinutes: _preferences.prayerReminderMinutes,
        method: _preferences.prayerMethod,
        madhab: _preferences.prayerMadhab,
      ),
    );

    _recompute();
    _startTicking();
    _followPosition();

    // Menjadwalkan ulang setiap kali layar dibuka adalah cara termurah menjaga
    // jendela tujuh hari tetap penuh: tidak ada pekerjaan latar belakang, dan
    // orang yang memakai pengingatnya pasti membuka layar ini sesekali.
    await _applyNotifications();

    // Jadwal sudah tampil dari posisi yang paling cepat tersedia; baru sekarang
    // GPS ditanya sungguh-sungguh. Urutannya sengaja begini: membaca GPS bisa
    // memakan belasan detik di dalam ruangan, dan menahan layar selama itu demi
    // selisih yang biasanya nol adalah pertukaran yang buruk. Bila jawabannya
    // nanti berbeda, layar memperbaiki dirinya sendiri.
    await _acquireCurrentPosition();
  }

  /// Membaca GPS dan memperbarui jadwal bila posisinya berbeda bermakna.
  Future<void> _acquireCurrentPosition() async {
    try {
      final position = await _location.getCurrentPosition();
      await _adopt(
        latitude: position.latitude,
        longitude: position.longitude,
        source: PrayerLocationSource.live,
      );
    } on Object {
      // Izin ditolak atau sinyal tidak didapat. Jadwal yang sudah tampil tetap
      // benar untuk posisi yang dipakai menghitungnya, dan pita di layar sudah
      // menyatakan posisi itu dari mana asalnya.
    }
  }

  /// Mengikuti perpindahan pengguna selama layar terbuka.
  ///
  /// Berlangganan aliran yang sudah dinyalakan cubit geofence alih-alih
  /// menyalakan pelacakan sendiri: dua pelanggan pada satu aliran tidak
  /// menambah beban baterai, sementara memulai pelacakan kedua akan memunculkan
  /// dialog izin di layar yang tidak ada hubungannya dengan permainan.
  void _followPosition() {
    _positionSubscription ??= _location.positionStream.listen((position) {
      final latitude = state.latitude;
      final longitude = state.longitude;

      if (latitude != null && longitude != null) {
        final moved = LocationService.distanceMeters(
          fromLat: latitude,
          fromLon: longitude,
          toLat: position.latitude,
          toLon: position.longitude,
        );
        if (moved < _significantMoveM &&
            state.source == PrayerLocationSource.live) {
          return;
        }
      }

      unawaited(
        _adopt(
          latitude: position.latitude,
          longitude: position.longitude,
          source: PrayerLocationSource.live,
        ),
      );
    });
  }

  /// Memakai koordinat baru: menyimpannya, menghitung ulang, menjadwalkan ulang.
  Future<void> _adopt({
    required double latitude,
    required double longitude,
    required PrayerLocationSource source,
  }) async {
    final unchanged = state.latitude == latitude &&
        state.longitude == longitude &&
        state.source == source;
    if (unchanged) return;

    if (source == PrayerLocationSource.live) {
      await _preferences.setPrayerLocation(
        latitude: latitude,
        longitude: longitude,
      );
    }

    emit(
      state.copyWith(
        latitude: latitude,
        longitude: longitude,
        source: source,
        isLoading: false,
      ),
    );

    _recompute();
    await _applyNotifications();
  }

  /// Membaca ulang posisi atas permintaan pengguna.
  Future<void> refreshLocation() async {
    emit(state.copyWith(isLoading: true));
    await _acquireCurrentPosition();

    // Kegagalan membaca GPS tidak menghapus jadwal yang sudah tampil: yang lama
    // tetap benar untuk posisi yang dipakai menghitungnya. Yang perlu dipastikan
    // hanyalah penanda memuat berhenti berputar.
    if (state.isLoading) emit(state.copyWith(isLoading: false));
  }

  // ── Setelan ───────────────────────────────────────────────────

  Future<NotificationPermission?> setNotificationsEnabled(
      {required bool enabled}) async {
    if (!enabled) {
      await _preferences.setPrayerNotificationsEnabled(enabled: false);
      emit(state.copyWith(notificationsEnabled: false));
      await _applyNotifications();
      return null;
    }

    // Izin diminta lebih dulu. Menyalakan saklar sebelum izinnya ada akan
    // menghasilkan layar yang mengaku sudah mengingatkan padahal tidak ada satu
    // pun notifikasi yang bisa muncul.
    final permission = await _notifications.requestPermission();
    if (permission == NotificationPermission.denied) {
      emit(state.copyWith(notificationsEnabled: false, permission: permission));
      return permission;
    }

    await _preferences.setPrayerNotificationsEnabled(enabled: true);
    emit(state.copyWith(notificationsEnabled: true, permission: permission));
    await _applyNotifications();
    return permission;
  }

  Future<void> setPrayerEnabled(Prayer prayer, {required bool enabled}) async {
    await _preferences.setPrayerEnabled(prayer, enabled: enabled);
    emit(state.copyWith(enabledPrayers: _readEnabledPrayers()));
    await _applyNotifications();
  }

  Future<void> setReminderMinutes(int minutes) async {
    await _preferences.setPrayerReminderMinutes(minutes);
    emit(state.copyWith(reminderMinutes: minutes));
    await _applyNotifications();
  }

  Future<void> setMethod(CalculationMethod method) async {
    await _preferences.setPrayerMethod(method);
    emit(state.copyWith(method: method));
    _recompute();
    await _applyNotifications();
  }

  Future<void> setMadhab(AsrMadhab madhab) async {
    await _preferences.setPrayerMadhab(madhab);
    emit(state.copyWith(madhab: madhab));
    _recompute();
    await _applyNotifications();
  }

  // ── Bagian dalam ──────────────────────────────────────────────

  /// Koordinat yang bisa dipakai sekarang juga, tanpa menunggu apa pun.
  ///
  /// Urutannya menurun dari yang paling dapat dipercaya: posisi yang sudah
  /// dipancarkan GPS pada sesi ini, lalu posisi terakhir yang tersimpan, lalu
  /// Jakarta. Yang terakhir jarang benar, tetapi jauh lebih berguna daripada
  /// layar kosong bagi orang yang sedang mencari tahu jam berapa Maghrib —
  /// dan layar selalu menyatakan terang-terangan bahwa itu hanya patokan.
  (double, double, PrayerLocationSource) _seedLocation() {
    final known = _location.lastKnown;
    if (known != null) {
      return (known.latitude, known.longitude, PrayerLocationSource.live);
    }

    final saved = _preferences.prayerLocation;
    if (saved != null) {
      return (saved.latitude, saved.longitude, PrayerLocationSource.saved);
    }

    return (
      _fallbackLatitude,
      _fallbackLongitude,
      PrayerLocationSource.fallback
    );
  }

  Set<Prayer> _readEnabledPrayers() =>
      Prayer.notifiable.where(_preferences.prayerEnabled).toSet();

  void _recompute() {
    final latitude = state.latitude;
    final longitude = state.longitude;
    if (latitude == null || longitude == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final calculator = PrayerTimesCalculator(
      latitude: latitude,
      longitude: longitude,
      // Offset dibaca dari perangkat, bukan dari basis data zona waktu: yang
      // ditampilkan di layar harus sama dengan jam yang tampak di bilah status.
      utcOffset: now.timeZoneOffset,
      method: state.method,
      madhab: state.madhab,
    );

    emit(
      state.copyWith(
        today: calculator.forDate(today),
        tomorrow: calculator.forDate(
          DateTime(today.year, today.month, today.day + 1),
        ),
        now: now,
      ),
    );
  }

  void _startTicking() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();

      // Lewat tengah malam jadwalnya bukan lagi jadwal hari ini. Memeriksa
      // tanggalnya di sini membuat layar berganti sendiri tanpa perlu ditutup.
      final today = state.today;
      if (today != null &&
          (today.date.day != now.day || today.date.month != now.month)) {
        _recompute();
        return;
      }

      emit(state.copyWith(now: now));
    });
  }

  Future<void> _applyNotifications() async {
    final latitude = state.latitude;
    final longitude = state.longitude;
    if (latitude == null || longitude == null) return;

    await _notifications.reschedule(latitude: latitude, longitude: longitude);
    emit(state.copyWith(scheduledCount: await _notifications.scheduledCount()));
  }

  @override
  Future<void> close() async {
    _ticker?.cancel();
    await _positionSubscription?.cancel();
    return super.close();
  }
}
