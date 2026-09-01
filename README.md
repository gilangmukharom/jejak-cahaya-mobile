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
| Production            | `https://api.jejakcahaya.id/api/v1`   |

> Untuk perangkat fisik dengan backend HTTP (bukan HTTPS), Android 9+ memblokir
> cleartext secara bawaan. Tambahkan `android:usesCleartextTraffic="true"` pada
> `<application>` di `AndroidManifest.xml` **hanya untuk build debug**.

### Perintah

```bash
flutter analyze          # analisis statis
flutter test             # unit + widget test
dart format lib test     # format kode
flutter build apk --release
flutter build ipa
```

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
│   ├── services/                # LocationService (GPS, geofence, bearing)
│   ├── storage/                 # Token (terenkripsi) & preferensi
│   └── widgets/                 # Widget bersama
└── features/
    ├── auth/                    # Masuk, daftar, sesi
    ├── game/                    # Geofence gate, peta, radar, hasil penemuan
    ├── scanner/                 # Pemindai QR
    ├── collection/              # Galeri koleksi
    ├── mission/                 # Daftar & detail misi
    ├── quiz/                    # Pengerjaan quiz
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

`GeofenceCubit` memantau aliran posisi, sehingga gerbang terbuka sendiri begitu
pemain melangkah masuk ke area masjid. Pemeriksaan ke server dijarangkan
(minimal 8 detik) agar berjalan menyusuri halaman masjid tidak menghasilkan
puluhan permintaan per menit.

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
      Geofence Gate  ──(di luar area)──► Layar terkunci + jarak ke masjid
             │
       (di dalam area)
             ▼
   ┌──── Home Shell (4 tab) ────┐
   │  Peta · Koleksi · Misi · Profil
   └────────────┬───────────────┘
                │  (FAB pindai)
                ▼
         Pemindai QR ──► Hasil Penemuan ──► Quiz ──► Peta
                  └──► Ditolak (alasan + petunjuk) ──► Pindai lagi
```

---

## Izin

| Izin      | Alasan                                                             |
| --------- | ------------------------------------------------------------------ |
| Lokasi    | Geofence masjid (Layer 1) dan proximity checkpoint (Layer 2)        |
| Kamera    | Memindai QR checkpoint (Layer 3)                                   |

Sudah dikonfigurasi di `AndroidManifest.xml` dan `ios/Runner/Info.plist`.
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
