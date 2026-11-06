# Sumber ikon peluncur

Ketiga berkas di sini **hanya dipakai saat build** oleh `flutter_launcher_icons`,
dan sengaja diletakkan di luar `assets/` — direktori `assets/icons/` terdaftar
di `pubspec.yaml`, sehingga apa pun yang ditaruh di sana ikut dibundel ke dalam
APK. Ikon peluncur tidak pernah dibaca saat aplikasi berjalan, jadi membundelnya
hanya menambah ukuran unduhan tanpa guna.

| Berkas | Dipakai untuk |
| --- | --- |
| `app_icon.png` | iOS, dan Android sebelum adaptive icon (API < 26) |
| `app_icon_background.png` | Lapisan latar adaptive icon Android |
| `app_icon_foreground.png` | Lapisan marka adaptive icon Android — transparan |

## Kenapa marka pada foreground lebih kecil

Android menggambar kedua lapisan pada kanvas 108 dp lalu memangkasnya dengan
bentuk yang berbeda-beda tiap peluncur — bulat, squircle, kotak membulat — dan
menggesernya saat animasi parallax. Hanya lingkaran berdiameter sekitar 66 dp di
tengah yang dijamin selalu terlihat. Karena itu marka pada `app_icon_foreground.png`
tingginya 0,58 kanvas, sementara pada `app_icon.png` 0,735: dengan ukuran yang
sama, ujung pin akan terpotong di sebagian perangkat.

Kubah pada lapisan foreground benar-benar berlubang (alpha nol), bukan diisi
hijau. Bila diisi warna solid, ia akan terlihat sebagai tempelan yang tidak ikut
bergerak begitu peluncur menggeser lapisan latar.

## Membuat ulang

```bash
flutter pub get
dart run flutter_launcher_icons
```

Perintah itu menimpa `android/app/src/main/res/mipmap-*/` dan
`ios/Runner/Assets.xcassets/AppIcon.appiconset/`. Ubah berkas di sini lebih dulu,
jangan menyunting hasil keluarannya — hasil keluaran akan tertimpa.
