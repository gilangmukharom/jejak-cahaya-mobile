import 'package:equatable/equatable.dart';

/// Waktu-waktu yang ditampilkan pada jadwal harian.
///
/// [imsak] dan [terbit] bukan waktu sholat, tetapi ikut dihitung: keduanya
/// menandai batas — imsak menutup waktu makan sahur, terbit menutup waktu
/// Subuh. Menghilangkannya membuat jadwal kehilangan informasi yang justru
/// paling sering dicari saat Ramadan.
enum Prayer {
  imsak('imsak', 'Imsak'),
  subuh('subuh', 'Subuh'),
  terbit('terbit', 'Terbit'),
  dzuhur('dzuhur', 'Dzuhur'),
  ashar('ashar', 'Ashar'),
  maghrib('maghrib', 'Maghrib'),
  isya('isya', 'Isya');

  const Prayer(this.key, this.label);

  /// Kunci penyimpanan preferensi — ditulis eksplisit, bukan `name`, agar
  /// mengganti nama konstantanya tidak diam-diam menghapus setelan pengguna.
  final String key;

  /// Nama yang tampil di layar.
  final String label;

  /// Apakah waktu ini adalah panggilan sholat wajib.
  ///
  /// Hanya yang bernilai true yang boleh dijadwalkan sebagai notifikasi adzan;
  /// imsak dan terbit adalah penanda, bukan panggilan.
  bool get isObligatory => switch (this) {
        Prayer.subuh ||
        Prayer.dzuhur ||
        Prayer.ashar ||
        Prayer.maghrib ||
        Prayer.isya =>
          true,
        _ => false,
      };

  /// Waktu-waktu yang bisa dinyalakan notifikasinya, berurutan sepanjang hari.
  static const List<Prayer> notifiable = [
    Prayer.subuh,
    Prayer.dzuhur,
    Prayer.ashar,
    Prayer.maghrib,
    Prayer.isya,
  ];

  static Prayer? fromKey(String key) {
    for (final prayer in Prayer.values) {
      if (prayer.key == key) return prayer;
    }
    return null;
  }
}

/// Mazhab penentu awal waktu Ashar.
///
/// Bedanya hanya satu angka: panjang bayangan sebuah benda relatif terhadap
/// tingginya saat Ashar masuk. Syafi'i memakai satu kali, Hanafi dua kali —
/// yang membuat Ashar menurut Hanafi jatuh sekitar satu jam lebih lambat.
enum AsrMadhab {
  syafii('syafii', 'Syafi\'i, Maliki, Hanbali', 1),
  hanafi('hanafi', 'Hanafi', 2);

  const AsrMadhab(this.key, this.label, this.shadowFactor);

  final String key;
  final String label;
  final int shadowFactor;

  static AsrMadhab fromKey(String? key) => AsrMadhab.values.firstWhere(
        (madhab) => madhab.key == key,
        orElse: () => AsrMadhab.syafii,
      );
}

/// Cara Isya ditentukan.
///
/// Sebagian besar metode memakai sudut matahari di bawah ufuk. Umm al-Qura
/// tidak: ia memakai selang tetap sesudah Maghrib, karena di lintang Makkah
/// sudutnya menghasilkan waktu yang dianggap terlalu larut.
sealed class IshaRule {
  const IshaRule();
}

class IshaAngle extends IshaRule {
  const IshaAngle(this.degrees);
  final double degrees;
}

class IshaInterval extends IshaRule {
  const IshaInterval(this.minutes);
  final int minutes;
}

/// Parameter perhitungan — satu himpunan angka per lembaga hisab.
class CalculationMethod extends Equatable {
  const CalculationMethod({
    required this.key,
    required this.label,
    required this.description,
    required this.fajrAngle,
    required this.ishaRule,
    this.ihtiyatiMinutes = 0,
    this.maghribOffsetMinutes = 0,
    this.imsakBeforeFajrMinutes = 10,
  });

  final String key;
  final String label;
  final String description;

  /// Sudut matahari di bawah ufuk saat Subuh masuk.
  final double fajrAngle;

  final IshaRule ishaRule;

  /// Menit kehati-hatian yang ditambahkan Kemenag ke setiap waktu sholat.
  ///
  /// Bukan koreksi astronomis, melainkan pengaman: hisab menghitung waktu di
  /// satu titik koordinat, sementara jadwal dipakai satu kota penuh. Dua menit
  /// membuat orang di tepi barat kota tidak mendahului masuknya waktu.
  /// Pada waktu Terbit tanda ini dibalik — ditarik mundur, bukan dimajukan,
  /// karena Terbit adalah batas akhir Subuh.
  final int ihtiyatiMinutes;

  /// Selisih Maghrib terhadap terbenamnya matahari.
  final int maghribOffsetMinutes;

  final int imsakBeforeFajrMinutes;

  /// Kementerian Agama RI — dipakai seluruh jadwal resmi di Indonesia.
  static const CalculationMethod kemenag = CalculationMethod(
    key: 'kemenag',
    label: 'Kemenag RI',
    description: 'Subuh 20° · Isya 18° · ihtiyati 2 menit',
    fajrAngle: 20,
    ishaRule: IshaAngle(18),
    ihtiyatiMinutes: 2,
  );

  static const CalculationMethod muslimWorldLeague = CalculationMethod(
    key: 'mwl',
    label: 'Muslim World League',
    description: 'Subuh 18° · Isya 17°',
    fajrAngle: 18,
    ishaRule: IshaAngle(17),
  );

  static const CalculationMethod ummAlQura = CalculationMethod(
    key: 'umm_al_qura',
    label: 'Umm al-Qura, Makkah',
    description: 'Subuh 18,5° · Isya 90 menit setelah Maghrib',
    fajrAngle: 18.5,
    ishaRule: IshaInterval(90),
  );

  static const CalculationMethod egyptian = CalculationMethod(
    key: 'egyptian',
    label: 'Egyptian General Authority',
    description: 'Subuh 19,5° · Isya 17,5°',
    fajrAngle: 19.5,
    ishaRule: IshaAngle(17.5),
  );

  static const CalculationMethod isna = CalculationMethod(
    key: 'isna',
    label: 'ISNA, Amerika Utara',
    description: 'Subuh 15° · Isya 15°',
    fajrAngle: 15,
    ishaRule: IshaAngle(15),
  );

  /// Metode yang bisa dipilih pengguna, Kemenag lebih dulu karena aplikasi ini
  /// dipakai di Indonesia.
  static const List<CalculationMethod> all = [
    kemenag,
    muslimWorldLeague,
    egyptian,
    ummAlQura,
    isna,
  ];

  static CalculationMethod fromKey(String? key) => all.firstWhere(
        (method) => method.key == key,
        orElse: () => kemenag,
      );

  @override
  List<Object?> get props => [key];
}

/// Jadwal satu hari untuk satu koordinat.
///
/// Waktunya disimpan sebagai [DateTime] tanpa zona: jam dindingnya sudah benar
/// untuk zona yang dipakai saat menghitung. Penjadwal notifikasi membangun
/// ulang nilainya sebagai `TZDateTime` dengan komponen yang sama persis.
class DailyPrayerTimes extends Equatable {
  const DailyPrayerTimes({
    required this.date,
    required this.times,
    required this.latitude,
    required this.longitude,
    required this.method,
    required this.madhab,
  });

  /// Tanggal jadwal ini, dinormalkan ke tengah malam.
  final DateTime date;

  final Map<Prayer, DateTime> times;

  final double latitude;
  final double longitude;
  final CalculationMethod method;
  final AsrMadhab madhab;

  DateTime operator [](Prayer prayer) => times[prayer]!;

  /// Waktu sholat berikutnya terhitung dari [from], beserta waktunya.
  ///
  /// Mengembalikan null bila seluruh waktu wajib hari ini sudah lewat —
  /// pemanggilnya lalu meminta jadwal hari berikutnya. Pemisahan itu disengaja:
  /// kelas ini hanya tahu satu hari, dan tidak boleh menebak-nebak hari lain.
  (Prayer, DateTime)? nextAfter(DateTime from) {
    for (final prayer in Prayer.notifiable) {
      final time = times[prayer];
      if (time != null && time.isAfter(from)) return (prayer, time);
    }
    return null;
  }

  /// Waktu sholat yang sedang berjalan pada [at], atau null bila hari itu belum
  /// masuk waktu Subuh.
  (Prayer, DateTime)? currentAt(DateTime at) {
    (Prayer, DateTime)? current;
    for (final prayer in Prayer.notifiable) {
      final time = times[prayer];
      if (time != null && !time.isAfter(at)) current = (prayer, time);
    }
    return current;
  }

  @override
  List<Object?> get props => [date, times, latitude, longitude, method, madhab];
}
