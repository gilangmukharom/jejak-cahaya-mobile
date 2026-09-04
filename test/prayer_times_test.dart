import 'package:flutter_test/flutter_test.dart';
import 'package:jejak_cahaya/core/models/prayer_times.dart';
import 'package:jejak_cahaya/core/services/prayer_times_service.dart';

/// Jadwal sholat dihitung sepenuhnya di perangkat, jadi tidak ada server yang
/// bisa mengoreksinya kalau rumusnya salah — dan salahnya tidak akan terlihat
/// sebagai galat, hanya sebagai angka yang keliru beberapa menit. Pengujian di
/// bawah karena itu tidak berhenti pada "tidak melempar", melainkan memeriksa
/// sifat-sifat fisis yang harus dipenuhi berapa pun tanggal dan tempatnya.
void main() {
  // Monas, Jakarta Pusat.
  const jakartaLat = -6.1754;
  const jakartaLon = 106.8272;
  const wib = Duration(hours: 7);

  const jakarta = PrayerTimesCalculator(
    latitude: jakartaLat,
    longitude: jakartaLon,
    utcOffset: wib,
  );

  String clock(DateTime time) => '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  group('urutan waktu', () {
    // Empat tanggal yang mewakili dua titik balik matahari dan dua ekuinoks —
    // di situlah deklinasi matahari berada pada nilai ekstremnya, dan di situ
    // pula kesalahan tanda pada rumus paling mungkin menampakkan diri.
    final dates = [
      DateTime(2026, 3, 20),
      DateTime(2026, 6, 21),
      DateTime(2026, 9, 23),
      DateTime(2026, 12, 21),
    ];

    for (final date in dates) {
      final label = date.toIso8601String().substring(0, 10);

      test('menaik sepanjang hari pada $label', () {
        final schedule = jakarta.forDate(date);

        // Urutan pada enum sengaja sama dengan urutan kejadiannya sepanjang
        // hari, jadi daftarnya bisa diperiksa apa adanya.
        final ordered =
            Prayer.values.map((prayer) => schedule[prayer]).toList();

        for (var i = 1; i < ordered.length; i++) {
          expect(
            ordered[i].isAfter(ordered[i - 1]),
            isTrue,
            reason: '${Prayer.values[i].label} harus setelah '
                '${Prayer.values[i - 1].label}',
          );
        }

        // Seluruhnya masih pada tanggal yang sama; jadwal yang bocor ke hari
        // berikutnya berarti ada pembungkusan jam yang gagal.
        for (final time in ordered) {
          expect(time.day, date.day);
        }
      });
    }
  });

  test('Dzuhur berada di tengah antara terbit dan terbenam', () {
    final schedule = jakarta.forDate(DateTime(2026, 9, 4));

    final sunrise = schedule[Prayer.terbit];
    final sunset = schedule[Prayer.maghrib];
    final midpoint = sunrise.add(
      Duration(milliseconds: sunset.difference(sunrise).inMilliseconds ~/ 2),
    );

    // Terbit ditarik mundur dan Maghrib dimajukan masing-masing dua menit oleh
    // ihtiyati, jadi titik tengahnya bergeser sedikit — tetapi tidak lebih dari
    // beberapa menit dari Dzuhur hasil hisab.
    final gap = schedule[Prayer.dzuhur].difference(midpoint).inMinutes.abs();
    expect(gap, lessThanOrEqualTo(4));
  });

  test('jadwal Jakarta 4 September 2026 tidak bergeser diam-diam', () {
    // Nilai acuan, dikunci agar perubahan pada rumus terlihat sebagai
    // kegagalan uji alih-alih sebagai jadwal yang meleset di tangan pengguna.
    final schedule = jakarta.forDate(DateTime(2026, 9, 4));

    expect(clock(schedule[Prayer.imsak]), '04:27');
    expect(clock(schedule[Prayer.subuh]), '04:37');
    expect(clock(schedule[Prayer.terbit]), '05:49');
    expect(clock(schedule[Prayer.dzuhur]), '11:54');
    expect(clock(schedule[Prayer.ashar]), '15:12');
    expect(clock(schedule[Prayer.maghrib]), '17:55');
    expect(clock(schedule[Prayer.isya]), '19:04');
  });

  test('Imsak tepat sepuluh menit sebelum Subuh', () {
    final schedule = jakarta.forDate(DateTime(2026, 9, 4));

    expect(
      schedule[Prayer.subuh].difference(schedule[Prayer.imsak]),
      const Duration(minutes: 10),
    );
  });

  test('ihtiyati Kemenag memajukan waktu sholat tepat dua menit', () {
    // Metode pembanding: angka yang sama persis dengan Kemenag, hanya tanpa
    // menit kehati-hatian. Selisih yang muncul karena itu hanya bisa berasal
    // dari ihtiyati, bukan dari hal lain.
    const withoutIhtiyati = CalculationMethod(
      key: 'uji',
      label: 'Uji',
      description: 'Kemenag tanpa ihtiyati',
      fajrAngle: 20,
      ishaRule: IshaAngle(18),
    );

    final withIhtiyati = jakarta.forDate(DateTime(2026, 9, 4));
    final plain = const PrayerTimesCalculator(
      latitude: jakartaLat,
      longitude: jakartaLon,
      utcOffset: wib,
      method: withoutIhtiyati,
    ).forDate(DateTime(2026, 9, 4));

    for (final prayer in Prayer.notifiable) {
      expect(
        withIhtiyati[prayer].difference(plain[prayer]),
        const Duration(minutes: 2),
        reason: '${prayer.label} harus maju dua menit',
      );
    }

    // Terbit adalah batas akhir Subuh, jadi ihtiyati menariknya ke arah
    // sebaliknya.
    expect(
      plain[Prayer.terbit].difference(withIhtiyati[Prayer.terbit]),
      const Duration(minutes: 2),
    );
  });

  test('Ashar mazhab Hanafi jatuh lebih lambat daripada Syafii', () {
    final syafii = jakarta.forDate(DateTime(2026, 9, 4));
    final hanafi = const PrayerTimesCalculator(
      latitude: jakartaLat,
      longitude: jakartaLon,
      utcOffset: wib,
      madhab: AsrMadhab.hanafi,
    ).forDate(DateTime(2026, 9, 4));

    expect(hanafi[Prayer.ashar].isAfter(syafii[Prayer.ashar]), isTrue);

    // Bayangan dua kali tinggi benda menggeser Ashar sekitar satu jam di
    // lintang rendah — cukup jauh untuk memastikan faktornya benar-benar
    // dipakai, bukan sekadar diteruskan.
    final shift =
        hanafi[Prayer.ashar].difference(syafii[Prayer.ashar]).inMinutes;
    expect(shift, inInclusiveRange(40, 80));

    // Selain Ashar, tidak ada yang boleh berubah.
    expect(syafii[Prayer.maghrib], hanafi[Prayer.maghrib]);
    expect(syafii[Prayer.subuh], hanafi[Prayer.subuh]);
  });

  test('mengganti zona waktu menggeser seluruh jadwal sebesar selisihnya', () {
    final wibSchedule = jakarta.forDate(DateTime(2026, 9, 4));
    final witaSchedule = const PrayerTimesCalculator(
      latitude: jakartaLat,
      longitude: jakartaLon,
      utcOffset: Duration(hours: 8),
    ).forDate(DateTime(2026, 9, 4));

    for (final prayer in Prayer.values) {
      expect(
        witaSchedule[prayer].difference(wibSchedule[prayer]),
        const Duration(hours: 1),
        reason: prayer.label,
      );
    }
  });

  test('Isya Umm al-Qura jatuh 90 menit setelah Maghrib', () {
    final schedule = const PrayerTimesCalculator(
      latitude: 21.4225,
      longitude: 39.8262,
      utcOffset: Duration(hours: 3),
      method: CalculationMethod.ummAlQura,
    ).forDate(DateTime(2026, 9, 4));

    expect(
      schedule[Prayer.isya].difference(schedule[Prayer.maghrib]),
      const Duration(minutes: 90),
    );
  });

  test('London saat titik balik musim panas tetap menghasilkan jadwal utuh',
      () {
    // Pada tanggal ini matahari di London tidak pernah turun sampai 17° di
    // bawah ufuk, sehingga rumus sudutnya tidak punya solusi sama sekali. Tanpa
    // aturan pembagian malam, Subuh dan Isya akan menjadi NaN — dan NaN pada
    // sebuah jadwal tidak muncul sebagai galat, melainkan sebagai tanggal
    // tahun 1970 yang tampil begitu saja di layar.
    final schedule = const PrayerTimesCalculator(
      latitude: 51.5074,
      longitude: -0.1278,
      utcOffset: Duration(hours: 1),
      method: CalculationMethod.muslimWorldLeague,
    ).forDate(DateTime(2026, 6, 21));

    for (final prayer in Prayer.values) {
      expect(schedule[prayer].year, 2026, reason: prayer.label);
    }

    expect(schedule[Prayer.subuh].isBefore(schedule[Prayer.terbit]), isTrue);
    expect(schedule[Prayer.isya].isAfter(schedule[Prayer.maghrib]), isTrue);
  });

  group('waktu berikutnya', () {
    final schedule = jakarta.forDate(DateTime(2026, 9, 4));

    test('menunjuk sholat wajib terdekat setelah saat tertentu', () {
      final result = schedule.nextAfter(DateTime(2026, 9, 4, 12, 0));

      expect(result?.$1, Prayer.ashar);
      expect(clock(result!.$2), '15:12');
    });

    test('melewatkan Terbit, yang bukan panggilan sholat', () {
      final result = schedule.nextAfter(DateTime(2026, 9, 4, 5, 0));
      expect(result?.$1, Prayer.dzuhur);
    });

    test('kosong setelah Isya, agar pemanggil beralih ke jadwal besok', () {
      expect(schedule.nextAfter(DateTime(2026, 9, 4, 20, 0)), isNull);
    });

    test('waktu yang sedang berjalan adalah yang terakhir sudah masuk', () {
      expect(
        schedule.currentAt(DateTime(2026, 9, 4, 12, 0))?.$1,
        Prayer.dzuhur,
      );

      // Sebelum Subuh belum ada waktu yang berjalan pada hari itu.
      expect(schedule.currentAt(DateTime(2026, 9, 4, 3, 0)), isNull);
    });
  });

  test('forRange menghasilkan hari berturut-turut', () {
    final week = jakarta.forRange(DateTime(2026, 12, 29), 5);

    expect(week, hasLength(5));
    expect(week.first.date, DateTime(2026, 12, 29));
    // Melewati pergantian tahun tanpa perlu penanganan khusus.
    expect(week.last.date, DateTime(2027, 1, 2));
  });

  test('hanya lima waktu wajib yang bisa diberi notifikasi', () {
    expect(Prayer.notifiable, hasLength(5));
    expect(Prayer.notifiable.contains(Prayer.imsak), isFalse);
    expect(Prayer.notifiable.contains(Prayer.terbit), isFalse);
    expect(Prayer.notifiable.every((prayer) => prayer.isObligatory), isTrue);
  });

  test('kunci preferensi metode dan mazhab tahan terhadap nilai asing', () {
    // Kunci yang tidak dikenal bisa datang dari pemasangan lama atau dari
    // setelan yang pernah dihapus; jatuh ke bawaan jauh lebih baik daripada
    // melempar di tengah pemuatan layar.
    expect(CalculationMethod.fromKey(null), CalculationMethod.kemenag);
    expect(CalculationMethod.fromKey('tidak-ada'), CalculationMethod.kemenag);
    expect(
        CalculationMethod.fromKey('mwl'), CalculationMethod.muslimWorldLeague);

    expect(AsrMadhab.fromKey(null), AsrMadhab.syafii);
    expect(AsrMadhab.fromKey('hanafi'), AsrMadhab.hanafi);
  });
}
