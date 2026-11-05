# Sumber logo & ikon peluncur

## Desain — "Orbit Nusantara"

- **Pin lokasi emas**: pemain mendatangi tempat bersejarah yang nyata.
- **Bintang** di dalam medali navy: pahlawan yang ditemukan.
- **Cincin orbit**: *Nusantara Universe*.
- **Bulan merah-putih** yang mengitarinya: Indonesia.

Semua bentuknya vektor (SVG) di `logo_concepts.py`. Berkas yang sama juga
menyimpan dua konsep alternatif, `compass` (Kompas Penjelajah) dan `trail`
(Monogram Jejak).

## Berkas

| Berkas | Dipakai untuk |
| --- | --- |
| `app_icon.png` | iOS, dan Android sebelum adaptive icon (API < 26) |
| `app_icon_background.png` | Lapisan latar adaptive icon Android (Nusa Navy) |
| `app_icon_foreground.png` | Lapisan marka adaptive icon Android, transparan |
| `../assets/images/nusaverse_logo.png` | Logo di splash & halaman login, transparan |

Ketiga PNG di folder ini **hanya dipakai saat build** oleh
`flutter_launcher_icons`. Folder ini sengaja diletakkan di luar `assets/`, karena
apa pun di `assets/icons/` ikut dibundel ke dalam APK.

## Kenapa marka pada foreground lebih kecil

Android menggambar kedua lapisan pada kanvas 108 dp, lalu memangkasnya dengan
bentuk yang berbeda-beda di tiap peluncur (bulat, squircle, kotak membulat).
Hanya lingkaran berdiameter sekitar 66 dp di tengah yang dijamin selalu
terlihat. Karena itu skala marka di foreground 0,74 dan di `app_icon.png` 0,86.
Dengan skala 0,74, ujung orbit dan bulannya tetap berada di dalam zona aman.

## Membuat ulang

Rasterisasinya memakai Chrome/Edge headless, supaya gradien dan bayangan SVG
tampil persis seperti di peramban.

```bash
python -I launcher_icon/render_logo.py          # konsep orbit (bawaan)
python -I launcher_icon/render_logo.py compass  # atau konsep lain
dart run flutter_launcher_icons
```

Perintah terakhir menimpa `android/app/src/main/res/mipmap-*/` dan
`ios/Runner/Assets.xcassets/AppIcon.appiconset/`. Ubah sumbernya di sini, jangan
menyunting hasil keluarannya, karena hasil keluaran akan tertimpa.
