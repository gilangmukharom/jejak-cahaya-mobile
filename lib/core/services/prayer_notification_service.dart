import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer_times.dart';
import '../storage/app_preferences.dart';
import '../utils/id_date.dart';
import 'prayer_times_service.dart';

/// Hasil permintaan izin notifikasi, cukup rinci untuk dijelaskan ke pengguna.
enum NotificationPermission {
  /// Diizinkan, dan alarm presisi juga tersedia.
  granted,

  /// Notifikasi diizinkan, tetapi sistem hanya memberi alarm perkiraan.
  ///
  /// Notifikasinya tetap muncul, hanya bisa meleset beberapa menit karena
  /// Android menggabungkannya dengan alarm aplikasi lain demi baterai.
  grantedInexact,

  /// Ditolak — tidak ada notifikasi yang akan muncul.
  denied,
}

/// Menjadwalkan pengingat waktu sholat lewat alarm sistem.
///
/// Notifikasinya dipasang di muka untuk beberapa hari sekaligus, bukan dihitung
/// saat waktunya tiba. Alasannya sederhana: aplikasi ini tidak berjalan di
/// latar belakang, dan tidak boleh berjalan di latar belakang hanya untuk
/// menunggu jam empat pagi. Yang mengingat adalah sistem operasi; aplikasi
/// cukup menitipkan daftar waktunya.
///
/// Konsekuensinya, daftar itu harus diisi ulang secara berkala — dilakukan
/// setiap aplikasi dibuka. Jendela [_daysAhead] hari memberi kelonggaran yang
/// jauh melebihi kebiasaan orang membuka aplikasi permainan.
class PrayerNotificationService {
  PrayerNotificationService(this._preferences);

  final AppPreferences _preferences;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timeZoneReady = false;

  /// Berapa hari ke depan yang dijadwalkan sekaligus.
  static const int _daysAhead = 7;

  /// Awal rentang id notifikasi milik jadwal sholat.
  ///
  /// Dipisahkan dari nol supaya notifikasi lain yang mungkin ditambahkan kelak
  /// tidak diam-diam menimpa jadwal ini — dan supaya membatalkan jadwal cukup
  /// menyapu rentang ini, tanpa menyentuh notifikasi milik fitur lain.
  static const int _idBase = 71000;

  static const String _channelId = 'jc_prayer_times';

  /// Menyiapkan basis data zona waktu dan saluran notifikasi.
  ///
  /// Aman dipanggil berkali-kali; hanya putaran pertama yang bekerja.
  Future<void> initialize() async {
    if (_initialized) return;

    await _ensureTimeZone();

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Izin diminta belakangan, saat pengguna benar-benar menyalakan
          // notifikasi — bukan diam-diam saat aplikasi pertama dijalankan.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Saluran dibuat lebih dulu, bukan dibiarkan terbentuk sendiri saat
    // notifikasi pertama muncul. Setelan sebuah saluran di Android tidak bisa
    // diubah setelah dibuat, jadi lebih baik nilai yang benar sudah terpasang
    // sejak awal daripada mewarisi setelan bawaan yang tidak berbunyi.
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Waktu Sholat',
        description: 'Pengingat masuknya waktu sholat.',
        importance: Importance.max,
      ),
    );

    _initialized = true;
  }

  Future<void> _ensureTimeZone() async {
    if (_timeZoneReady) return;

    tz_data.initializeTimeZones();

    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } on Object catch (error) {
      // Perangkat yang melaporkan nama zona di luar basis data IANA tidak boleh
      // membuat seluruh fitur mati. `tz.local` lalu tetap UTC — dan karena
      // jadwalnya dihitung memakai offset dari `tz.local` yang sama, hasilnya
      // tetap menunjuk saat yang benar. Yang hilang hanyalah kemampuan
      // mengikuti pergantian waktu musim panas di zona tersebut.
      debugPrint('Zona waktu perangkat tidak dikenali: $error');
    }

    _timeZoneReady = true;
  }

  /// Meminta izin yang diperlukan agar notifikasi benar-benar muncul.
  ///
  /// Dua izin terpisah di Android, dan keduanya bisa ditolak sendiri-sendiri:
  /// izin menampilkan notifikasi (sejak Android 13) dan izin memasang alarm
  /// presisi (sejak Android 14). Tanpa yang kedua notifikasinya tetap muncul,
  /// hanya tidak tepat menit — dan itu perbedaan yang perlu dikatakan kepada
  /// pengguna, bukan disembunyikan.
  Future<NotificationPermission> requestPermission() async {
    await initialize();

    if (Platform.isIOS || Platform.isMacOS) {
      final granted = await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
      return granted
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return NotificationPermission.denied;

    final allowed = await android.requestNotificationsPermission() ?? false;
    if (!allowed) return NotificationPermission.denied;

    if (await android.canScheduleExactNotifications() ?? false) {
      return NotificationPermission.granted;
    }

    await android.requestExactAlarmsPermission();
    return await android.canScheduleExactNotifications() ?? false
        ? NotificationPermission.granted
        : NotificationPermission.grantedInexact;
  }

  /// Menghapus lalu memasang ulang seluruh pengingat menurut preferensi terkini.
  ///
  /// Dipanggil setiap kali ada yang berubah — setelan, koordinat, atau sekadar
  /// hari berganti. Menyapu bersih lebih dulu jauh lebih sederhana daripada
  /// mencoba menambal jadwal yang sudah terpasang, dan jumlahnya kecil.
  Future<void> reschedule({
    required double latitude,
    required double longitude,
  }) async {
    await initialize();
    await cancelAll();

    if (!_preferences.prayerNotificationsEnabled) return;

    final enabled = Prayer.notifiable
        .where(_preferences.prayerEnabled)
        .toList(growable: false);
    if (enabled.isEmpty) return;

    final reminder = Duration(minutes: _preferences.prayerReminderMinutes);
    final mode = await _scheduleMode();
    final now = tz.TZDateTime.now(tz.local);

    for (var dayIndex = 0; dayIndex < _daysAhead; dayIndex++) {
      final day = DateTime(now.year, now.month, now.day + dayIndex);

      final schedule = PrayerTimesCalculator(
        latitude: latitude,
        longitude: longitude,
        utcOffset: _offsetOn(day),
        method: _preferences.prayerMethod,
        madhab: _preferences.prayerMadhab,
      ).forDate(day);

      for (final prayer in enabled) {
        final time = schedule[prayer];
        final fireAt = tz.TZDateTime(
          tz.local,
          time.year,
          time.month,
          time.day,
          time.hour,
          time.minute,
        ).subtract(reminder);

        // Waktu yang sudah lewat tetap diterima Android dan langsung
        // dibunyikan — persis kebalikan dari yang diinginkan seseorang yang
        // baru saja mengubah setelan pada sore hari.
        if (!fireAt.isAfter(now)) continue;

        await _schedule(
          id: _idFor(dayIndex: dayIndex, prayer: prayer),
          fireAt: fireAt,
          prayer: prayer,
          time: time,
          reminder: reminder,
          mode: mode,
        );
      }
    }
  }

  Future<void> _schedule({
    required int id,
    required tz.TZDateTime fireAt,
    required Prayer prayer,
    required DateTime time,
    required Duration reminder,
    required AndroidScheduleMode mode,
  }) async {
    final clock = formatClock(time);

    final title = reminder == Duration.zero
        ? 'Waktu ${prayer.label} — $clock'
        : '${reminder.inMinutes} menit lagi ${prayer.label}';

    final body = reminder == Duration.zero
        ? 'Telah masuk waktu ${prayer.label} untuk wilayah Anda.'
        : 'Waktu ${prayer.label} masuk pukul $clock.';

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: fireAt,
        androidScheduleMode: mode,
        payload: prayer.key,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Waktu Sholat',
            channelDescription: 'Pengingat masuknya waktu sholat.',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
      );
    } on Object catch (error) {
      // Sebagian pabrikan membatasi jumlah alarm per aplikasi dan menolak yang
      // melebihi kuota. Menggagalkan seluruh penjadwalan karena satu penolakan
      // akan membuang hari-hari yang sudah berhasil terpasang.
      debugPrint('Gagal menjadwalkan ${prayer.label} pada $fireAt: $error');
    }
  }

  /// Memasang ulang jadwal dari koordinat yang tersimpan, bila ada.
  ///
  /// Dipanggil sekali saat aplikasi dijalankan. Tanpa ini, jendela tujuh hari
  /// akan habis diam-diam bagi orang yang membuka aplikasi tetapi tidak pernah
  /// membuka tab Ibadah — dan pengingatnya berhenti tanpa satu pun tanda.
  ///
  /// Tidak meminta izin dan tidak membaca GPS: keduanya memunculkan dialog, dan
  /// memunculkan dialog saat aplikasi baru dibuka adalah hal terakhir yang
  /// diinginkan seseorang.
  Future<void> refreshFromSavedLocation() async {
    if (!_preferences.prayerNotificationsEnabled) return;

    final saved = _preferences.prayerLocation;
    if (saved == null) return;

    await reschedule(latitude: saved.latitude, longitude: saved.longitude);
  }

  /// Membatalkan seluruh pengingat sholat, tanpa menyentuh notifikasi lain.
  Future<void> cancelAll() async {
    await initialize();

    for (var dayIndex = 0; dayIndex < _daysAhead; dayIndex++) {
      for (final prayer in Prayer.notifiable) {
        await _plugin.cancel(id: _idFor(dayIndex: dayIndex, prayer: prayer));
      }
    }
  }

  /// Jumlah pengingat yang benar-benar terpasang di sistem saat ini.
  ///
  /// Dipakai layar setelan untuk menunjukkan bahwa jadwalnya sungguh terpasang
  /// — satu-satunya cara membedakan "sudah dijadwalkan" dari "diam saja" tanpa
  /// menunggu sampai waktu sholat tiba.
  Future<int> scheduledCount() async {
    await initialize();

    final pending = await _plugin.pendingNotificationRequests();
    return pending
        .where((request) =>
            request.id >= _idBase &&
            request.id < _idBase + _daysAhead * Prayer.values.length)
        .length;
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final exact = await android?.canScheduleExactNotifications() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Selisih zona waktu terhadap UTC pada [day], menurut zona perangkat.
  ///
  /// Dibaca per tanggal, bukan sekali di awal: di zona yang mengenal waktu
  /// musim panas, jadwal seminggu ke depan bisa melewati pergantiannya, dan
  /// offset hari ini akan salah satu jam untuk sebagian hari yang dijadwalkan.
  Duration _offsetOn(DateTime day) =>
      tz.TZDateTime(tz.local, day.year, day.month, day.day, 12).timeZoneOffset;

  static int _idFor({required int dayIndex, required Prayer prayer}) =>
      _idBase + dayIndex * Prayer.values.length + prayer.index;
}
