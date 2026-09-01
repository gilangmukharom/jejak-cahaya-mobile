# ════════════════════════════════════════════════════════════════
#  Aturan R8 untuk build release.
#
#  Build debug tidak melalui R8 sama sekali, sehingga seluruh masalah di
#  berkas ini hanya muncul pada APK release — dan bentuknya menyesatkan:
#  kamera gagal dibuka dengan `genericError`, sebuah pesan yang tidak
#  menyebut kelas apa pun. Yang sebenarnya terjadi adalah kelas yang
#  hanya dipanggil lewat refleksi tidak terlihat oleh R8, dianggap tidak
#  terpakai, lalu dibuang.
# ════════════════════════════════════════════════════════════════

# ── CameraX ─────────────────────────────────────────────────────
# CameraX memuat implementasinya lewat nama kelas, bukan lewat rujukan
# langsung: `Camera2Config` dan kawan-kawannya dicari saat runtime. R8
# tidak bisa melihat rujukan semacam itu, jadi tanpa aturan ini penyedia
# kameranya tidak pernah terbentuk dan kamera tidak pernah menyala.
-keep class androidx.camera.** { *; }
-keep interface androidx.camera.** { *; }
-dontwarn androidx.camera.**

# ── ML Kit (pemindai barcode) ───────────────────────────────────
# Paket mobile_scanner sudah menyertakan aturannya sendiri, tetapi versi
# 5.x menuliskannya sebagai `com.google.mlkit.*` dengan satu titik — pola
# itu hanya cocok dengan kelas yang berada persis di paket tersebut, dan
# melewatkan seluruh sub-paketnya. Aturan di bawah memakai dua titik dan
# tetap dipertahankan di sini sebagai jaring pengaman, agar penurunan
# versi paket tidak diam-diam mengembalikan kegagalan yang sama.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.libraries.barhopper.** { *; }
-dontwarn com.google.mlkit.**

# ── Enum ────────────────────────────────────────────────────────
# Enum diserialkan dan dibaca kembali lewat nama, termasuk pada jembatan
# antara Dart dan Android.
-keepclassmembers class * extends java.lang.Enum {
    <fields>;
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
