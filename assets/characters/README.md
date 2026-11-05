# Potret Hero Card

Potret pahlawan untuk Hero Card, satu berkas WebP per pahlawan, dinamai
**persis seperti slug pahlawan di backend** (mis. `soekarno.webp`,
`cut-nyak-dien.webp`).

Folder ini kosong sejak rebrand NUSAVERSE: potret tokoh lama sudah dicabut,
dan potret pahlawan nasional belum dibuat. Sampai ada, Hero Card memakai ikon.

## Menambah potret

1. Simpan berkas di `assets/characters/<slug>.webp` — sisi terpanjang ±768 px,
   latar transparan.
2. Daftarkan **per berkas** di `pubspec.yaml` (bukan seluruh folder, supaya
   README ini tidak ikut dibundel ke APK).
3. Tambahkan barisnya di `_assets` pada
   [`lib/core/widgets/collectible_portrait.dart`](../../lib/core/widgets/collectible_portrait.dart).

Tes `test/collectible_portrait_test.dart` memastikan setiap potret yang
dipetakan benar-benar ada di bundel.

Sesuai konsep produk, desain karakter harus orisinal dan menghormati sejarah
serta atribut asli setiap pahlawan.
