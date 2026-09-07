# Jejak Cahaya — Mobile App

Aplikasi Flutter untuk **Jejak Cahaya — Islamic Explorer**: permainan edukasi
berbasis lokasi di area masjid.

**Flutter 3.44 · Dart 3.12 · Clean Architecture · BLoC**

---

## Menjalankan

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

Tidak ada langkah `build_runner` — proyek ini sengaja tidak memakai codegen,
jadi `flutter pub get` sudah cukup.

### Alamat backend

Konfigurasi masuk lewat `--dart-define`, bukan berkas `.env`, karena nilainya
tertanam saat build: build produksi tidak mungkin diam-diam menunjuk API lokal.

| Target                | `API_BASE_URL`                        |
| --------------------- | ------------------------------------- |
| Android Emulator      | `http://10.0.2.2:3000/api/v1`         |
| iOS Simulator         | `http://localhost:3000/api/v1`        |
| Perangkat fisik (LAN) | `http://<IP-komputer>:3000/api/v1`    |
| Production            | `https://api.jejak-cahaya.com/api/v1` |

> Untuk perangkat fisik dengan backend HTTP (bukan HTTPS), Android 9+ memblokir
> cleartext secara bawaan. Tambahkan `android:usesCleartextTraffic="true"` pada
> `<application>` di `AndroidManifest.xml` **hanya untuk build debug**.
>
> Di iOS penyumbatnya bernama App Transport Security, dan sudah dibuka
> secukupnya: `NSAllowsLocalNetworking` di `ios/Runner/Info.plist` mengizinkan
> HTTP hanya ke `localhost`, alamat `.local`, dan rentang IP privat — jadi
> Simulator dan perangkat di LAN yang sama langsung jalan, sementara build
> produksi yang menunjuk HTTPS tidak terpengaruh. Tidak ada yang perlu diubah
> untuk debug, dan tidak ada yang perlu dikembalikan sebelum rilis.

### Perintah

```bash
flutter analyze          # analisis statis
flutter test             # unit + widget test
dart format lib test     # format kode
flutter build apk --release
flutter build ipa
```

### Membangun untuk iOS

Butuh macOS dengan Xcode — `flutter build ipa` tidak bisa dijalankan dari
Windows atau Linux, dan tidak ada jalan pintas untuk itu.

```bash
flutter pub get
cd ios && pod install && cd ..     # sekali, dan setiap kali pubspec berubah
flutter build ipa --dart-define=API_BASE_URL=https://api.jejak-cahaya.com/api/v1
```

`pod install` tetap diperlukan meskipun proyek Xcode-nya sudah memakai Swift
Package Manager: `flutter_secure_storage` dan `path_provider_foundation` belum
menyediakan `Package.swift`, jadi keduanya hanya bisa masuk lewat CocoaPods.
Keduanya hidup berdampingan dalam satu build — lihat komentar di `ios/Podfile`.

Sebelum build pertama, buka `ios/Runner.xcworkspace` (**bukan** `.xcodeproj` —
target CocoaPods hanya ada di workspace) lalu isi *Signing & Capabilities* →
*Team*. Bundle ID-nya `id.jejakcahaya.jejakCahaya`; huruf kapital di tengah
bukan kekeliruan, melainkan konsekuensi iOS yang tidak menerima garis bawah
pada bundle ID, sementara Android memakai `id.jejakcahaya.jejak_cahaya`.

| Berkas                                   | Berisi                                                        |
| ---------------------------------------- | ------------------------------------------------------------- |
| `ios/Podfile`                            | Versi iOS minimum (13.0) dan pod untuk plugin non-SPM          |
| `ios/Runner/Info.plist`                  | Teks izin, orientasi potret, ATS, pernyataan kepatuhan ekspor  |
| `ios/Runner/AppDelegate.swift`           | Delegate `UNUserNotificationCenter` — tanpanya pengingat sholat tidak tampil selagi aplikasi dibuka |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard` | Latar peluncuran `#06251C`, disamakan dengan Android    |

iOS 13.0 adalah lantainya, ditentukan oleh `maplibre_gl`, `sensors_plus`, dan
`flutter_local_notifications`. Angka itu ditulis di tiga tempat yang harus
sejalan: `platform` di `Podfile`, `IPHONEOS_DEPLOYMENT_TARGET` di
`Runner.xcodeproj`, dan paket SPM yang dibangkitkan Flutter.

---

## Struktur

```
lib/
├── main.dart                    # Entry point
├── app/
│   ├── app.dart                 # MaterialApp.router + lokalisasi
│   ├── router/                  # go_router + guard autentikasi terpusat
│   └── theme/                   # Palet warna & ThemeData
├── core/
│   ├── config/                  # AppConfig (dart-define)
│   ├── constants/               # Jalur endpoint API
│   ├── di/injection.dart        # Pendaftaran get_it (manual, satu berkas)
│   ├── error/                   # Failure, exception, dan pemetaannya
│   ├── models/                  # Model domain lintas fitur
│   ├── network/                 # Dio + interceptor, ApiClient
│   ├── services/                # LocationService, jadwal sholat, kiblat, notifikasi
│   ├── storage/                 # Token (terenkripsi) & preferensi
│   └── widgets/                 # Widget bersama
└── features/
    ├── auth/                    # Masuk, daftar, sesi
    ├── game/                    # Geofence gate, peta, radar, hasil penemuan
    ├── scanner/                 # Pemindai QR
    ├── collection/              # Galeri koleksi
    ├── mission/                 # Daftar & detail misi
    ├── quiz/                    # Pengerjaan quiz
    ├── worship/                 # Jadwal sholat & arah kiblat
    ├── leaderboard/             # Papan peringkat
    └── profile/                 # Profil & pencapaian
```

### Anatomi sebuah fitur

```
<fitur>/
├── data/                # Repository — memanggil API, memetakan error
└── presentation/
    ├── cubit/           # State management
    ├── pages/           # Layar
    └── widgets/         # Widget khusus fitur
```

Model domain diletakkan di `core/models/` alih-alih di dalam masing-masing
fitur, karena hampir semuanya melintasi batas fitur — `Collectible` misalnya
dipakai oleh scanner, koleksi, katalog, dan misi sekaligus. Menduplikasinya per
fitur hanya akan menghasilkan empat definisi yang harus dijaga tetap sinkron.

---

## Keputusan Teknis

### Tanpa codegen

Tidak memakai `freezed`, `json_serializable`, maupun `injectable`. Model dan
pendaftaran DI ditulis eksplisit. Konsekuensinya lebih banyak baris kode, tetapi
proyek langsung dapat dijalankan setelah `flutter pub get`, tidak ada berkas
`.g.dart` yang bisa basi, dan setiap galat kompilasi menunjuk ke kode yang
benar-benar ditulis manusia.

Parsing JSON memakai pembantu toleran di `core/models/json_utils.dart`: satu
kolom bertipe tak terduga menghasilkan nilai bawaan, bukan menjatuhkan layar.

### Enum punya anggota `unknown`

Setiap enum memetakan nilai tak dikenal ke `unknown` alih-alih melempar
exception. Kurator dapat menambah kategori tokoh kapan saja sementara pengguna
belum tentu memperbarui aplikasinya — kartu bertipe baru sebaiknya tetap tampil.

### Perhitungan jarak diduplikasi dari backend

`LocationService.distanceMeters` dan `bearingDegrees` menyalin rumus Haversine
di `backend/src/common/utils/geo.ts` **dengan sengaja**, dan diuji terhadap
nilai acuan yang sama (`test/location_service_test.dart`).

Aplikasi memakainya hanya untuk umpan balik langsung — jarak pada radar dan
indikator "sudah dekat". Keputusan yang mengikat tetap diambil server. Menjaga
keduanya identik memastikan layar tidak pernah menjanjikan sesuatu yang kemudian
ditolak backend.

### Peta digambar sendiri dari data OpenStreetMap yang dibundel

Layar penjelajahan memenuhi seluruh layar dan berperilaku seperti peta
permainan: kamera mengikuti pemain, ikut berputar ke arah ia berjalan, dan
antarmuka lain mengambang di atasnya.

Petanya **tidak** menarik gambar jadi dari server tile. Yang dibundel adalah
`assets/map/basemap.pmtiles` — data vektor Protomaps (turunan OpenStreetMap)
untuk area bermain — lalu digambar di perangkat memakai `vector_map_tiles`
dengan gaya di `lib/app/theme/game_map_style.dart`. Tiga akibatnya:

- **Tanpa kunci API, tanpa biaya berulang.** Tidak ada layanan pihak ketiga yang
  dihubungi. Perlu dicatat bahwa `tile.openstreetmap.org` — yang dipakai versi
  sebelumnya — melarang pemakaian oleh aplikasi yang didistribusikan, jadi
  pendekatan ini sekaligus menyelesaikan persoalan itu.
- **Peta berjalan tanpa jaringan.** Pelataran masjid kerap bersinyal buruk.
- **Paletnya ditentukan sendiri:** rumput hijau, air toska, jalan krem, dan
  seluruh label POI dimatikan — tidak ada teks di atas peta selain milik
  permainan sendiri.

Cara membuat ulang arsipnya untuk masjid baru ada di
[`assets/map/README.md`](assets/map/README.md). Atribusi OpenStreetMap wajib
ditampilkan (ODbL) dan sudah terpasang lewat `MapAttribution`.

### Geofence terus dipantau, bukan sekali cek

`GeofenceCubit` memantau aliran posisi, sehingga peta terbuka sendiri begitu
pemain melangkah masuk ke area masjid. Pemeriksaan ke server dijarangkan
(minimal 8 detik di luar area, 30 detik di dalam) agar berjalan menyusuri
halaman masjid tidak menghasilkan puluhan permintaan per menit.

Cubit-nya berumur sepanjang aplikasi dan didaftarkan di `core/di/injection.dart`,
bukan dibuat per layar: tiga layar bergantung pada jawabannya sekaligus —
gerbang, peta, dan pemindai — dan satu instance per layar berarti tiga langganan
GPS berjalan berbarengan serta tiga jawaban yang bisa berbeda.

### Di luar area, yang terkunci hanya peta

Berada di luar radius masjid **tidak** menutup aplikasi. Yang tertutup hanyalah
peta permainan: petanya tetap tergambar tetapi dikaburkan, dan di atasnya
muncul kartu berisi nama masjid terdekat yang bisa dimainkan beserta sisa jarak
menuju tepi areanya (dihitung lokal dengan rumus yang sama dengan server, jadi
angkanya tidak berselisih dengan jawaban resmi).

Jadwal sholat, arah kiblat, koleksi, misi, papan peringkat, dan profil tetap
terbuka dari mana saja. Pemindai pun tidak dihalangi — penolakannya datang dari
server dengan alasan yang sudah spesifik.

### Jadwal sholat dihitung di perangkat

`PrayerTimesCalculator` menghitung posisi matahari sendiri (algoritma yang sama
dengan PrayTimes.org), jadi jadwalnya benar tanpa satu pun permintaan jaringan
— penting karena ini satu-satunya bagian aplikasi yang harus tetap bekerja di
ruang bawah masjid tanpa sinyal.

Metode bawaan Kemenag RI (Subuh 20°, Isya 18°, ihtiyati 2 menit); MWL, Egyptian,
Umm al-Qura, dan ISNA bisa dipilih, begitu pula mazhab waktu Ashar. Lintang
tinggi ditangani dengan aturan pembagian malam berbasis sudut, sehingga London
di bulan Juni tetap menghasilkan jadwal utuh alih-alih NaN.

Pengingatnya dititipkan ke alarm sistem lewat `flutter_local_notifications` —
tujuh hari sekaligus, diisi ulang setiap aplikasi dibuka. Aplikasi tidak berjalan
di latar belakang untuk menunggu jam empat pagi.

### Kompas kiblat dirakit sendiri

Arah hadap dihitung dari akselerometer + magnetometer dengan rumus yang sama
dengan `SensorManager.getRotationMatrix` di Android, jadi hasilnya sudah
terkoreksi kemiringan. Paket kompas siap pakai yang beredar tidak dipakai:
semuanya sudah lama tidak dirawat dan tidak punya `namespace`, sehingga gagal
dibangun pada Android Gradle Plugin yang dipakai proyek ini.

### Refresh token disatukan

Interceptor menyatukan permintaan refresh yang bersamaan menjadi satu panggilan.
Backend merotasi refresh token setiap kali dipakai dan mencabut seluruh sesi
bila token bekas dipakai ulang — dua refresh paralel akan membuat pengguna
ter-logout paksa.

---

## Alur Layar

```
Splash ──► Login / Daftar
             │
             ▼
      Geofence Gate  (hanya menunggu sinyal GPS — tidak menahan siapa pun)
             │
             ▼
   ┌──── Home Shell (4 tab) ─────────┐
   │  Peta · Koleksi · Ibadah · Profil
   └────────────┬────────────────────┘
                │
     ┌──────────┴───────────┬──────────────────┐
     ▼                      ▼                  ▼
  Peta                   Ibadah            (FAB pindai)
   ├─(di dalam area)      ├─ Jadwal sholat      │
   │   checkpoint, radar  ├─ Arah kiblat        ▼
   └─(di luar area)       └─ Pengaturan   Pemindai QR
       peta blur +           notifikasi     ├─► Hasil Penemuan ──► Quiz
       masjid terdekat                      └─► Ditolak (alasan + petunjuk)
       + sisa jarak

Misi tidak lagi punya tab sendiri: dijangkau dari bilah misi di atas peta
dan dari halaman Profil.
```

---

## Izin

| Izin                    | Alasan                                                       |
| ----------------------- | ------------------------------------------------------------ |
| Lokasi                  | Geofence masjid (Layer 1), proximity checkpoint (Layer 2), dan koordinat jadwal sholat & arah kiblat |
| Kamera                  | Memindai QR checkpoint (Layer 3)                             |
| Notifikasi              | Pengingat waktu sholat — diminta hanya saat pengguna menyalakannya |
| `SCHEDULE_EXACT_ALARM`  | Agar pengingat berbunyi tepat menit. Ditolak pun jadwalnya tetap terpasang, hanya dengan ketelitian beberapa menit |
| `RECEIVE_BOOT_COMPLETED`| Memasang ulang pengingat setelah perangkat dinyalakan; sistem menghapus seluruh alarm saat mati |
| Sensor magnet           | Kompas kiblat. Tidak diwajibkan — tanpa magnetometer, sudutnya tetap ditampilkan sebagai angka |

Sudah dikonfigurasi di `AndroidManifest.xml` dan `ios/Runner/Info.plist`.
Dua baris terakhir tabel adalah izin khusus Android; di iOS penjadwalan alarm
presisi sudah tercakup oleh izin notifikasi, dan jadwalnya bertahan melewati
restart tanpa izin tambahan. Sebaliknya `NSMotionUsageDescription` hanya ada di
iOS — Android tidak meminta izin apa pun untuk membaca magnetometer.
Lokasi presisi (`ACCESS_FINE_LOCATION`) diperlukan karena radius checkpoint
hanya ±25 m — akurasi kasar meleset terlalu jauh untuk itu.

Izin yang ditolak permanen ditangani terpisah: aplikasi mengarahkan pengguna ke
pengaturan sistem, karena meminta ulang tidak akan memunculkan dialog apa pun.

---

## Yang Belum Ada

- **Aset gambar tokoh** — `assets/images/` masih kosong; kartu koleksi memakai
  ikon sebagai penanda. Tata letaknya sudah final, tinggal mengisi `imageUrl`.
- **Audio story** (Tahap 2) — kolom `audioUrl` sudah dibawa model, pemutarnya belum dibuat.
- **AR Camera** (Tahap 3) — kolom `modelUrl` sudah tersedia untuk aset glTF.
- **Test integrasi** — layar penuh bergantung pada GetIt, jaringan, dan GPS,
  sehingga memerlukan server tiruan, bukan widget test.
