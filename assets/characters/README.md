# Potret tokoh

Enam berkas WebP, satu per tokoh, dinamai **persis seperti slug collectible di
backend**. Pemetaannya ada di
[`lib/core/widgets/collectible_portrait.dart`](../../lib/core/widgets/collectible_portrait.dart)
dan ditulis satu per satu, bukan diturunkan dari nama berkas: sumbernya bernama
"Ibnu Batutah" dan "Muh Al Fatih", sementara slug-nya `ibnu-battuta` dan
`muhammad-al-fatih`.

| | |
| --- | --- |
| Sumber | `Karakter Tokoh Islam/` di akar repo — PNG 1920x1920, RGB |
| Hasil | WebP sisi terpanjang 768 px, dengan alpha |
| Ukuran | ±396 KB untuk enam berkas (sumbernya ±13 MB) |

## Kenapa dibundel, bukan diunduh

Potret ini muncul tepat setelah pemain memindai QR di pelataran masjid — tempat
sinyal kerap buruk. Gambar yang gagal dimuat mengubah layar imbalan menjadi
kotak kosong, persis pada momen yang paling ingin dirayakan. Alasannya sama
dengan yang membuat basemap peta ikut dibundel.

Skema backend menyediakan `Collectible.imageUrl` dan secara arsitektur itulah
tempat yang "benar", tetapi ia menuntut jaringan pada saat yang paling tidak
bisa diandalkan.

## Membuat ulang

Sumbernya berlatar **putih solid**, bukan transparan. Latar itu dihapus dengan
**flood fill dari tepi**, bukan ambang batas warna — dan perbedaannya
menentukan: sorban Ibnu Battuta dan Sunan Kalijaga juga nyaris putih, sehingga
ambang batas polos akan ikut melubanginya. Yang dibuang hanya gugusan piksel
putih yang tersambung sampai ke tepi gambar; sorban di tengah wajah tidak
tersambung ke mana pun, jadi ia selamat.

```python
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

img = Image.open(sumber)
img.thumbnail((768, 768), Image.LANCZOS)

rgb = np.asarray(img.convert('RGB')).astype(np.int16)
putih = (rgb.min(axis=2) >= 232) & ((rgb.max(axis=2) - rgb.min(axis=2)) <= 14)

labels, _ = ndimage.label(putih)
tepi = np.concatenate([labels[0, :], labels[-1, :], labels[:, 0], labels[:, -1]])
latar = np.isin(labels, [int(v) for v in np.unique(tepi) if v != 0])

hasil = img.convert('RGBA')
hasil.putalpha(Image.fromarray(np.where(latar, 0, 255).astype(np.uint8))
               .filter(ImageFilter.GaussianBlur(0.8)))   # lembutkan tepi
hasil = hasil.crop(hasil.split()[3].getbbox())            # pangkas ke isi
hasil.save(tujuan, 'WEBP', quality=88, method=6)
```

### Catatan Salahuddin Al-Ayyubi

Sumbernya berupa komposisi berkuda seluruh badan, sementara lima lainnya potret
setengah badan. Pada slot kartu yang sama wajahnya menjadi jauh lebih kecil dan
kartunya terasa tidak sederet, jadi berkas ini **dipotong** ke bagian kepala
sampai dada setelah latarnya dihapus — kira-kira `x` 0,265–0,710 dan `y`
0,005–0,590 dari gambar yang sudah dipangkas. Berkas sumbernya tidak diubah.

## Menambah tokoh baru

1. Letakkan PNG-nya di `Karakter Tokoh Islam/`.
2. Jalankan pengolahan di atas, simpan sebagai `<slug>.webp` di folder ini.
3. Daftarkan slug-nya pada peta `_assets` di `collectible_portrait.dart`.
4. Tambahkan slug-nya ke `seededSlugs` pada
   `test/collectible_portrait_test.dart`.

Melewatkan langkah 3 tidak menimbulkan galat — tokohnya hanya akan menampilkan
ikon, dan itu mudah disangka "gambarnya memang belum ada".
