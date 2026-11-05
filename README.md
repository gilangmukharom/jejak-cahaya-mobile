# NUSAVERSE — Mobile App

Aplikasi Flutter untuk **NUSAVERSE — Discover Heroes. Explore Indonesia.**:
game edukasi berbasis lokasi untuk menemukan pahlawan Indonesia lewat AR di
lokasi-lokasi bersejarah, lengkap dengan NUSA POINTS dan Reward Store.

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
*Team*. Bundle ID iOS dan application ID Android sama-sama `id.nusaverse.app`.

| Berkas                                   | Berisi                                                        |
| ---------------------------------------- | ------------------------------------------------------------- |
| `ios/Podfile`                            | Versi iOS minimum (13.0) dan pod untuk plugin non-SPM          |
| `ios/Runner/Info.plist`                  | Teks izin, orientasi potret, ATS, pernyataan kepatuhan ekspor  |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard` | Latar peluncuran, disamakan dengan Android               |

iOS 13.0 adalah lantainya, ditentukan oleh `maplibre_gl` dan `flutter_tts`.
Angka itu ditulis di tiga tempat yang harus
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
│   ├── services/                # LocationService, AppSettings (aksesibilitas), narasi TTS
│   ├── storage/                 # Token (terenkripsi) & preferensi
│   └── widgets/                 # Widget bersama
└── features/
    ├── auth/                    # Masuk, daftar, sesi
    ├── game/                    # Geofence gate, peta, radar, hasil penemuan
    ├── locations/               # Daftar lokasi bersejarah & kemajuan pemain
    ├── scanner/                 # Pemindai QR
    ├── ar/                      # AR hero (native ARCore) & cadangan 3D
    ├── collection/              # Hero Collection
    ├── mission/                 # Daftar & detail misi
    ├── quiz/                    # Pengerjaan kuis
    ├── rewards/                 # NUSA POINTS, Reward Store, tantangan
    ├── leaderboard/             # Papan peringkat
    └── profile/                 # Profil, pencapaian, pengaturan & aksesibilitas
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
- **Peta berjalan tanpa jaringan.** Pelataran lokasi kerap bersinyal buruk.
- **Paletnya ditentukan sendiri:** rumput hijau, air toska, jalan krem, dan
  seluruh label POI dimatikan — tidak ada teks di atas peta selain milik
  permainan sendiri.

Cara membuat ulang arsipnya untuk lokasi baru ada di
[`assets/map/README.md`](assets/map/README.md). Atribusi OpenStreetMap wajib
ditampilkan (ODbL) dan sudah terpasang lewat `MapAttribution`.

### Geofence terus dipantau, bukan sekali cek

`GeofenceCubit` memantau aliran posisi, sehingga peta terbuka sendiri begitu
pemain melangkah masuk ke area lokasi. Pemeriksaan ke server dijarangkan
(minimal 8 detik di luar area, 30 detik di dalam) agar berjalan menyusuri
halaman lokasi tidak menghasilkan puluhan permintaan per menit.

Cubit-nya berumur sepanjang aplikasi dan didaftarkan di `core/di/injection.dart`,
bukan dibuat per layar: tiga layar bergantung pada jawabannya sekaligus —
gerbang, peta, dan pemindai — dan satu instance per layar berarti tiga langganan
GPS berjalan berbarengan serta tiga jawaban yang bisa berbeda.

### Banyak lokasi, dipilih sendiri oleh aplikasi

Permainan berjalan di beberapa lokasi. Pemain tidak diminta memilih apa pun:
`GeofenceCubit` menghitung lokasi terdekat dari posisinya pada setiap pembaruan
GPS, dan lokasi itulah yang dibuka. Berpindah lokasi cukup dengan datang ke sana.

Layar **Lokasi Penjelajahan** (`features/locations/`) menampilkan seluruh lokasi
terurut dari yang terdekat, masing-masing dengan cincin progresnya sendiri —
berapa titik ditemukan, berapa misi selesai, berapa XP diperoleh *di lokasi itu*.
Dari sana sebuah lokasi bisa dipilih manual untuk dilihat isinya sebelum berangkat.

Pilihan manual itu punya satu aturan yang menentukan: ia dilepas begitu pemain
benar-benar melangkah masuk ke area lokasi lain. Berdiri di dalam pelataran sebuah
lokasi adalah pernyataan yang lebih kuat daripada pilihan yang dibuat kemarin dari
rumah — tanpa aturan itu, seseorang akan berdiri di lokasi tujuannya sambil melihat
layar yang menyatakan ia berada di luar area, milik lokasi yang salah.

Layar ini memakai ulang `GeofenceCubit`, bukan cubit sendiri. Cubit itu sudah
memegang daftar lokasi, posisi pemain, dan lokasi yang sedang dibuka; sumber kedua
berarti dua layar bisa menjawab berbeda atas pertanyaan "saya sedang main di mana",
dan yang salah selalu terlihat lebih meyakinkan karena ia yang paling baru digambar.

### Di luar area, yang terkunci hanya peta

Berada di luar radius lokasi **tidak** menutup aplikasi. Yang tertutup hanyalah
peta permainan: petanya tetap tergambar tetapi dikaburkan, dan di atasnya
muncul kartu berisi nama lokasi terdekat yang bisa dimainkan beserta sisa jarak
menuju tepi areanya (dihitung lokal dengan rumus yang sama dengan server, jadi
angkanya tidak berselisih dengan jawaban resmi).

Hero Collection, Reward Store, tantangan, misi, papan peringkat, dan profil
tetap terbuka dari mana saja. Pemindai pun tidak dihalangi — penolakannya datang dari
server dengan alasan yang sudah spesifik.

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
   ┌──── Home Shell (4 tab + tombol pindai) ─────┐
   │  NUSA WORLD · Hero Collection · Reward · Profil
   └──────────────┬──────────────────────────────┘
                  │
     ┌────────────┴──────────┬───────────────────────┐
     ▼                       ▼                       ▼
  NUSA WORLD              Reward Store           (tombol pindai)
   ├─(di dalam area)       ├─ Katalog & tukar        │
   │   titik hero, radar   ├─ Penukaranku (kode)     ▼
   └─(di luar area)        ├─ Riwayat poin      Pemindai QR
       peta blur +         └─ Tantangan           ├─► AR hero + kisah ──► Hadiah XP & poin ──► Kuis
       lokasi terdekat                            └─► Ditolak (alasan + petunjuk;
       + sisa jarak                                    hero yang sudah dimiliki → "Lihat dalam AR")

Profil: misi, tantangan, pencapaian, peringkat, Pengaturan & Aksesibilitas.
```

---

## Izin

| Izin    | Alasan |
| ------- | ------ |
| Lokasi  | Geofence lokasi bersejarah (Layer 1) dan proximity checkpoint (Layer 2) |
| Kamera  | Memindai QR checkpoint (Layer 3) dan AR hero |

Sudah dikonfigurasi di `AndroidManifest.xml` dan `ios/Runner/Info.plist`.
Lokasi presisi (`ACCESS_FINE_LOCATION`) diperlukan karena radius checkpoint
hanya ±25 m — akurasi kasar meleset terlalu jauh untuk itu. Manifest juga
mendeklarasikan kueri `TTS_SERVICE` agar audio narasi menemukan mesin suara di
Android 11+.

Izin yang ditolak permanen ditangani terpisah: aplikasi mengarahkan pengguna ke
pengaturan sistem, karena meminta ulang tidak akan memunculkan dialog apa pun.

---

## Yang Belum Ada

- **Ilustrasi pahlawan** — Hero Card memakai monogram inisial sampai potret
  orisinal tersedia (lihat `assets/characters/README.md`).
- **Model 3D per pahlawan** — semua pahlawan memakai model bawaan; model lain
  diunggah dan dipilih per pahlawan lewat panel admin.
- **Test integrasi** — layar penuh bergantung pada GetIt, jaringan, dan GPS,
  sehingga memerlukan server tiruan, bukan widget test.
