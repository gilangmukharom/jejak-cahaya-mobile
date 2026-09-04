import 'dart:math' as math;

import '../models/prayer_times.dart';

/// Menghitung jadwal sholat dari posisi matahari — seluruhnya di perangkat.
///
/// Tidak ada permintaan jaringan di sini, dan itu disengaja. Jadwal sholat
/// adalah satu-satunya bagian aplikasi yang harus tetap benar ketika pemain
/// berada di ruang bawah masjid tanpa sinyal, atau ketika servernya sedang
/// mati. Rumusnya sendiri sudah mapan sejak lama dan tidak memerlukan data
/// apa pun selain koordinat, tanggal, dan selisih zona waktu.
///
/// Perhitungannya mengikuti algoritma yang sama dengan PrayTimes.org: posisi
/// matahari dari deret rendah (akurat beberapa detik busur untuk keperluan ini),
/// lalu waktu ketika matahari mencapai sudut tertentu di bawah ufuk.
///
/// Nilai yang dikembalikan adalah jam dinding setempat untuk zona yang
/// diberikan lewat [utcOffset] — bukan UTC, dan bukan waktu perangkat.
/// Pemanggilnya yang bertanggung jawab memberi offset yang benar untuk tanggal
/// tersebut; itulah yang membuat jadwal tetap benar di kota yang mengenal waktu
/// musim panas, tanpa kelas ini perlu tahu apa-apa soal zona waktu.
class PrayerTimesCalculator {
  const PrayerTimesCalculator({
    required this.latitude,
    required this.longitude,
    required this.utcOffset,
    this.method = CalculationMethod.kemenag,
    this.madhab = AsrMadhab.syafii,
  });

  final double latitude;
  final double longitude;

  /// Selisih zona waktu terhadap UTC pada tanggal yang dihitung.
  final Duration utcOffset;

  final CalculationMethod method;
  final AsrMadhab madhab;

  /// Sudut pusat matahari di bawah ufuk saat piringannya menyentuh cakrawala.
  ///
  /// 0,833° = setengah diameter matahari (0,266°) ditambah pembiasan atmosfer
  /// (0,567°). Tanpa keduanya, matahari akan dinyatakan terbenam ketika masih
  /// terlihat jelas di langit.
  static const double _riseSetAngle = 0.833;

  /// Jadwal untuk satu tanggal. Komponen jam pada [date] diabaikan.
  DailyPrayerTimes forDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);

    // Julian date tengah malam waktu setempat, dikoreksi ke bujur pengamat.
    // Koreksi bujur ini yang membuat perhitungan berlaku untuk titik tertentu,
    // bukan untuk garis tengah zona waktunya.
    final jdate =
        _julianDate(day.year, day.month, day.day) - longitude / (15 * 24);

    // Tebakan awal dalam jam, lalu disempurnakan satu putaran. Satu putaran
    // sudah cukup: deklinasi matahari bergeser kurang dari 0,02° per jam, jauh
    // di bawah ketelitian yang bisa dibedakan pada jadwal bersatuan menit.
    var times = const _Times(
      imsak: 5,
      fajr: 5,
      sunrise: 6,
      dhuhr: 12,
      asr: 13,
      sunset: 18,
      isha: 18,
    );
    times = _compute(jdate, times);

    // Dari jam matahari ke jam dinding: geser sesuai zona waktu, lalu balikkan
    // koreksi bujur yang tadi dipakai.
    final shift = utcOffset.inMinutes / 60 - longitude / 15;
    times = times.map((hour) => hour + shift);

    // Lintang tinggi: di atas ±48° ada tanggal ketika matahari tidak pernah
    // turun sampai 18° di bawah ufuk, sehingga Subuh dan Isya tidak punya
    // solusi. Aturan berbasis sudut membagi malam secara proporsional, dan
    // tidak mengubah apa pun di lintang Indonesia — di sana ambangnya tidak
    // pernah tersentuh.
    times = _adjustHighLatitudes(times);

    final maghribHour = times.sunset + method.maghribOffsetMinutes / 60;
    final ishaHour = switch (method.ishaRule) {
      IshaAngle() => times.isha,
      IshaInterval(minutes: final minutes) => maghribHour + minutes / 60,
    };

    // Ihtiyati membuat waktu sholat maju, dan penanda batas (Terbit) mundur —
    // keduanya bergerak ke arah yang lebih hati-hati, bukan ke arah yang sama.
    final ihtiyati = method.ihtiyatiMinutes;

    final resolved = <Prayer, DateTime>{
      Prayer.imsak:
          _at(day, times.fajr, ihtiyati - method.imsakBeforeFajrMinutes),
      Prayer.subuh: _at(day, times.fajr, ihtiyati),
      Prayer.terbit: _at(day, times.sunrise, -ihtiyati, roundUp: false),
      Prayer.dzuhur: _at(day, times.dhuhr, ihtiyati),
      Prayer.ashar: _at(day, times.asr, ihtiyati),
      Prayer.maghrib: _at(day, maghribHour, ihtiyati),
      Prayer.isya: _at(day, ishaHour, ihtiyati),
    };

    return DailyPrayerTimes(
      date: day,
      times: resolved,
      latitude: latitude,
      longitude: longitude,
      method: method,
      madhab: madhab,
    );
  }

  /// Jadwal [count] hari berturut-turut mulai dari [start].
  ///
  /// Dipakai penjadwal notifikasi, yang harus memasang alarm untuk beberapa
  /// hari ke depan sekaligus — sistem tidak menyediakan cara menjadwalkan
  /// "setiap hari pada waktu yang berbeda-beda".
  List<DailyPrayerTimes> forRange(DateTime start, int count) => List.generate(
        count,
        (index) => forDate(
          DateTime(start.year, start.month, start.day + index),
        ),
        growable: false,
      );

  // ── Inti perhitungan ──────────────────────────────────────────

  _Times _compute(double jdate, _Times guess) {
    final portion = guess.map((hour) => hour / 24);

    final fajr = _sunAngleTime(jdate, method.fajrAngle, portion.fajr,
        counterClockwise: true);
    final sunrise = _sunAngleTime(jdate, _riseSetAngle, portion.sunrise,
        counterClockwise: true);
    final dhuhr = _midDay(jdate, portion.dhuhr);
    final asr = _asrTime(jdate, portion.asr);
    final sunset = _sunAngleTime(jdate, _riseSetAngle, portion.sunset);
    final isha = switch (method.ishaRule) {
      IshaAngle(degrees: final degrees) =>
        _sunAngleTime(jdate, degrees, portion.isha),
      IshaInterval() => sunset,
    };

    return _Times(
      imsak: fajr ?? double.nan,
      fajr: fajr ?? double.nan,
      sunrise: sunrise ?? double.nan,
      dhuhr: dhuhr,
      asr: asr ?? double.nan,
      sunset: sunset ?? double.nan,
      isha: isha ?? double.nan,
    );
  }

  /// Tengah hari matahari: saat matahari melewati meridian pengamat.
  double _midDay(double jdate, double portion) {
    final equation = _sunPosition(jdate + portion).equationOfTime;
    return _fixHour(12 - equation);
  }

  /// Jam ketika matahari berada [angle] derajat di bawah ufuk.
  ///
  /// Mengembalikan null bila tidak ada solusi — matahari tidak pernah serendah
  /// itu pada tanggal tersebut, yang hanya terjadi di lintang tinggi.
  double? _sunAngleTime(
    double jdate,
    double angle,
    double portion, {
    bool counterClockwise = false,
  }) {
    final declination = _sunPosition(jdate + portion).declination;
    final noon = _midDay(jdate, portion);

    final numerator = -_sin(angle) - _sin(declination) * _sin(latitude);
    final denominator = _cos(declination) * _cos(latitude);
    if (denominator == 0) return null;

    final ratio = numerator / denominator;
    if (ratio < -1 || ratio > 1) return null;

    final offset = _acos(ratio) / 15;
    return noon + (counterClockwise ? -offset : offset);
  }

  /// Ashar: saat bayangan sebuah benda sepanjang bayangan tengah harinya
  /// ditambah [AsrMadhab.shadowFactor] kali tinggi bendanya.
  double? _asrTime(double jdate, double portion) {
    final declination = _sunPosition(jdate + portion).declination;
    final angle = -_acot(
      madhab.shadowFactor + _tan((latitude - declination).abs()),
    );
    return _sunAngleTime(jdate, angle, portion);
  }

  _Times _adjustHighLatitudes(_Times times) {
    if (times.sunrise.isNaN || times.sunset.isNaN) return times;

    // Panjang malam: dari terbenam hari ini sampai terbit esok.
    final night = _fixHour(times.sunrise - times.sunset);

    var fajr = times.fajr;
    final fajrLimit = night / 60 * method.fajrAngle;
    if (fajr.isNaN || _fixHour(times.sunrise - fajr) > fajrLimit) {
      fajr = times.sunrise - fajrLimit;
    }

    var isha = times.isha;
    if (method.ishaRule case IshaAngle(degrees: final degrees)) {
      final ishaLimit = night / 60 * degrees;
      if (isha.isNaN || _fixHour(isha - times.sunset) > ishaLimit) {
        isha = times.sunset + ishaLimit;
      }
    }

    return _Times(
      imsak: fajr,
      fajr: fajr,
      sunrise: times.sunrise,
      dhuhr: times.dhuhr,
      asr: times.asr,
      sunset: times.sunset,
      isha: isha,
    );
  }

  /// Mengubah jam pecahan menjadi [DateTime] pada [day], dibulatkan ke menit.
  ///
  /// Waktu sholat dibulatkan ke atas dan penanda batas ke bawah, sehingga
  /// pembulatan tidak pernah membuat sebuah waktu terlihat masuk lebih cepat
  /// daripada hasil hisabnya.
  ///
  /// Menitnya diserahkan ke konstruktor [DateTime], bukan ditambahkan lewat
  /// [DateTime.add]. Bedanya baru terasa di zona waktu yang mengenal waktu
  /// musim panas: `add` menambah durasi sungguhan, sehingga jadwal pada hari
  /// pergantian akan bergeser satu jam, sementara konstruktornya bekerja pada
  /// jam dinding — dan jam dinding itulah yang dimaksud sebuah jadwal sholat.
  DateTime _at(DateTime day, double hour, int offsetMinutes,
      {bool roundUp = true}) {
    final totalMinutes = hour * 60;
    final rounded = roundUp ? totalMinutes.ceil() : totalMinutes.floor();
    return DateTime(day.year, day.month, day.day, 0, rounded + offsetMinutes);
  }

  // ── Posisi matahari ───────────────────────────────────────────

  /// Deklinasi matahari dan perata waktu untuk sebuah Julian date.
  ///
  /// Deret pendek dari *Astronomical Almanac*; galatnya di bawah 0,01° untuk
  /// rentang tahun yang wajar — beberapa detik pada jadwal, tak terlihat pada
  /// tampilan bersatuan menit.
  _SunPosition _sunPosition(double julianDate) {
    final d = julianDate - 2451545.0;

    // Anomali rata-rata dan bujur rata-rata matahari.
    final g = _fixAngle(357.529 + 0.98560028 * d);
    final q = _fixAngle(280.459 + 0.98564736 * d);

    // Bujur ekliptika sejati.
    final l = _fixAngle(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g));

    // Kemiringan sumbu bumi, menyusut sangat lambat.
    final obliquity = 23.439 - 0.00000036 * d;

    final rightAscension = _atan2(_cos(obliquity) * _sin(l), _cos(l)) / 15;

    return _SunPosition(
      declination: _asin(_sin(obliquity) * _sin(l)),
      equationOfTime: q / 15 - _fixHour(rightAscension),
    );
  }

  /// Julian date pada tengah malam UT.
  static double _julianDate(int year, int month, int day) {
    var y = year;
    var m = month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }

    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();

    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        day +
        b -
        1524.5;
  }

  // ── Trigonometri dalam derajat ────────────────────────────────
  // Seluruh rumus astronomi di atas ditulis dalam derajat. Membungkus konversi
  // radian di sini membuat rumusnya bisa dibandingkan baris demi baris dengan
  // rujukannya, alih-alih dipenuhi `* pi / 180` yang mengaburkan isinya.

  static double _rad(double degrees) => degrees * math.pi / 180;
  static double _deg(double radians) => radians * 180 / math.pi;

  static double _sin(double degrees) => math.sin(_rad(degrees));
  static double _cos(double degrees) => math.cos(_rad(degrees));
  static double _tan(double degrees) => math.tan(_rad(degrees));

  static double _asin(double value) => _deg(math.asin(value));
  static double _acos(double value) => _deg(math.acos(value));
  static double _atan2(double y, double x) => _deg(math.atan2(y, x));
  static double _acot(double value) => _deg(math.atan2(1, value));

  static double _fixAngle(double degrees) => _wrap(degrees, 360);
  static double _fixHour(double hours) => _wrap(hours, 24);

  static double _wrap(double value, double range) {
    final result = value - range * (value / range).floor();
    return result < 0 ? result + range : result;
  }
}

class _SunPosition {
  const _SunPosition({
    required this.declination,
    required this.equationOfTime,
  });

  /// Derajat.
  final double declination;

  /// Jam.
  final double equationOfTime;
}

/// Kumpulan waktu dalam satuan jam pecahan, dipakai selama perhitungan.
class _Times {
  const _Times({
    required this.imsak,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.sunset,
    required this.isha,
  });

  final double imsak;
  final double fajr;
  final double sunrise;
  final double dhuhr;
  final double asr;
  final double sunset;
  final double isha;

  _Times map(double Function(double hour) transform) => _Times(
        imsak: transform(imsak),
        fajr: transform(fajr),
        sunrise: transform(sunrise),
        dhuhr: transform(dhuhr),
        asr: transform(asr),
        sunset: transform(sunset),
        isha: transform(isha),
      );
}
