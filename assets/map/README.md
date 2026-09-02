# Basemap offline (`basemap.pmtiles`)

Peta pada layar penjelajahan digambar dari berkas ini, bukan diunduh dari server
tile. Isinya data vektor **Protomaps Basemap v4** — turunan OpenStreetMap —
untuk area bermain saja.

| | |
| --- | --- |
| Berkas | `basemap.pmtiles` |
| Cakupan | `106.568, -6.156` → `106.786, -6.062` (±24 × 10 km, Sepatan – Masjid Al-Ikhlas PIK) |
| Zoom | 0–15 (ditampilkan sampai zoom 19 lewat penggambaran ulang di perangkat) |
| Ukuran | ±8,1 MB |
| Sumber | `https://build.protomaps.com/20260901.pmtiles` (basemap v4.15.2) |
| Lisensi | ODbL — atribusi OpenStreetMap **wajib** ditampilkan |

## Mengapa dibundel, bukan diunduh

Tiga alasan, berurutan menurut bobotnya:

1. **Tidak ada kunci API dan tidak ada biaya berulang.** Tidak ada layanan pihak
   ketiga yang dihubungi, jadi tidak ada kuota yang bisa habis saat pemain
   bertambah. Perlu dicatat bahwa server tile `tile.openstreetmap.org` — yang
   dipakai versi sebelumnya — **melarang** pemakaian oleh aplikasi yang
   didistribusikan; berkas ini sekaligus menyelesaikan persoalan itu.
2. **Berjalan tanpa jaringan.** Pelataran masjid kerap bersinyal buruk. Peta
   yang gagal memuat di sana akan menghentikan permainan tepat pada saat peta
   paling dibutuhkan.
3. **Paletnya milik kita.** Karena isinya geometri dan bukan gambar jadi,
   tampilannya ditentukan sepenuhnya oleh `lib/app/theme/game_map_style.dart`.

## Membuat ulang berkasnya

Diperlukan ketika masjid baru ditambahkan di luar cakupan sekarang, atau ketika
data OpenStreetMap ingin disegarkan.

1. Unduh CLI `pmtiles` dari
   <https://github.com/protomaps/go-pmtiles/releases> (pilih berkas untuk sistem
   operasi Anda, lalu ekstrak).

2. Tentukan build harian terbaru. Daftarnya ada di
   <https://maps.protomaps.com/builds>, atau lewat berkas JSON-nya langsung:

   ```bash
   curl -s https://build-metadata.protomaps.dev/builds.json | tail -c 400
   ```

   Ambil nilai `key` paling akhir, misalnya `20260901.pmtiles`.

3. Ekstrak wilayahnya. Daftar wilayah yang ikut dibundel ada di
   [`coverage.geojson`](coverage.geojson) — berkas itulah sumber kebenarannya,
   bukan angka yang diketik di baris perintah:

   ```bash
   pmtiles extract https://build.protomaps.com/20260901.pmtiles basemap.pmtiles \
     --region=coverage.geojson \
     --maxzoom=15
   ```

   Tambahkan `--dry-run` lebih dulu untuk melihat perkiraan ukurannya tanpa
   mengunduh apa pun.

4. Timpa `assets/map/basemap.pmtiles` dengan hasilnya, lalu **hentikan aplikasi
   sepenuhnya dan jalankan ulang** — bukan hot reload. Berkasnya akan disalin
   ulang ke penyimpanan perangkat secara otomatis karena ukurannya berbeda;
   lihat `BasemapService._materializeAsset`.

## Menambah wilayah baru

Sebuah kotak per lokasi, bukan satu kotak besar yang memuat semuanya. Ini bukan
soal kerapian melainkan soal ukuran: kotak yang membentang dari satu masjid ke
masjid lain ikut membawa seluruh daerah di antaranya. Sebagai gambaran, dengan
`--maxzoom=15`:

| Wilayah | Ukuran |
| --- | --- |
| Satu kotak 10 × 10 km | ±5 MB |
| Jakarta kota | ±57 MB |
| Jabodetabek | ±105 MB |

Karena itu `coverage.geojson` berbentuk `FeatureCollection`: tiap lokasi menjadi
satu `Feature` tersendiri, dan yang terunduh hanya kotak-kotak itu — bukan ruang
kosong di antaranya. Dua lokasi berjarak 60 km tetap menghasilkan berkas ±10 MB,
bukan ±100 MB.

Untuk menambah lokasi, salin satu blok `Feature` lalu ganti keempat sudutnya.
Kotak ±10 × 10 km berarti menambah dan mengurangi **0,045 derajat** dari titik
pusatnya. Perhatikan bahwa GeoJSON menulis koordinat sebagai
`[bujur, lintang]` — kebalikan dari urutan yang biasa dipakai peta — dan titik
pertama harus diulang di akhir untuk menutup poligonnya.

```json
{
  "type": "Feature",
  "properties": { "nama": "Lokasi pengujian" },
  "geometry": {
    "type": "Polygon",
    "coordinates": [[
      [106.7, -6.3], [106.8, -6.3], [106.8, -6.2], [106.7, -6.2], [106.7, -6.3]
    ]]
  }
}
```

> Saat menguji di luar wilayah yang dibundel, aplikasi menampilkan pemberitahuan
> di atas peta beserta **koordinat Anda saat itu**. Angka itulah yang dipakai
> sebagai titik pusat kotak baru — tidak perlu mencarinya lewat aplikasi lain.

### Catatan ukuran

Setiap tingkat zoom tambahan kira-kira **melipatduakan** ukuran berkas, dan
ukurannya sebanding dengan luas area. `--maxzoom=15` sudah cukup: permainan
berlangsung di zoom ~18, dan aplikasi menggambar ulang geometri zoom 15 pada
perbesaran berapa pun sehingga hasilnya tetap tajam.

Bila suatu saat cakupannya harus mencakup banyak kota sekaligus, berkasnya akan
menjadi terlalu besar untuk dibundel. Ketika itu terjadi, unggah `.pmtiles`-nya
ke penyimpanan objek sendiri (Cloudflare R2, S3) dan ganti sumber di
`BasemapService` menjadi URL — paket `pmtiles` sudah mendukung pembacaan lewat
HTTP range request, jadi hanya potongan yang dilihat pemain yang benar-benar
diunduh.

## Atribusi

Wajib, dan sudah terpasang pada `MapAttribution` di lembar checkpoint:

> © OpenStreetMap · Protomaps

Jangan hapus tanpa mengganti dengan bentuk atribusi lain yang setara — ODbL
mensyaratkannya.
