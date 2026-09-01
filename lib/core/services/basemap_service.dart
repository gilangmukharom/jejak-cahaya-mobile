import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pmtiles/pmtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

/// Hasil pemuatan basemap offline.
///
/// Sengaja bukan sekadar `TileProviders?`. Peta yang gagal dimuat tampil
/// sebagai bidang hijau polos — tidak bisa dibedakan dari daerah yang kebetulan
/// lengang, dan tidak memberi tahu apa pun tentang penyebabnya. Objek ini
/// membawa serta alasan kegagalan dan cakupan wilayah arsip, sehingga layar
/// peta bisa menjelaskan dirinya sendiri alih-alih diam.
class Basemap {
  const Basemap._({this.providers, this.southWest, this.northEast, this.failureReason});

  /// Basemap yang siap dipakai.
  const Basemap.ready({
    required TileProviders providers,
    required LatLng southWest,
    required LatLng northEast,
  }) : this._(providers: providers, southWest: southWest, northEast: northEast);

  /// Basemap yang tidak bisa dimuat, beserta alasannya dalam bahasa manusia.
  const Basemap.unavailable(String reason) : this._(failureReason: reason);

  final TileProviders? providers;

  /// Sudut wilayah yang dicakup arsip. Null bila arsipnya gagal dibuka.
  final LatLng? southWest;
  final LatLng? northEast;

  final String? failureReason;

  bool get isReady => providers != null;

  /// Apakah sebuah koordinat berada di dalam wilayah yang dipetakan.
  ///
  /// Arsipnya hanya memuat area bermain — beberapa kilometer di sekitar masjid,
  /// bukan seluruh dunia. Di luar itu memang tidak ada yang bisa digambar, dan
  /// membedakan keadaan ini dari kegagalan memuat adalah setengah dari
  /// pekerjaan mencari tahu kenapa peta tampak kosong.
  bool covers(double latitude, double longitude) {
    final sw = southWest;
    final ne = northEast;
    if (sw == null || ne == null) return false;

    return latitude >= sw.latitude &&
        latitude <= ne.latitude &&
        longitude >= sw.longitude &&
        longitude <= ne.longitude;
  }

  /// Uraian wilayah cakupan untuk ditampilkan saat pemain berada di luarnya.
  String get coverageLabel {
    final sw = southWest;
    final ne = northEast;
    if (sw == null || ne == null) return 'tidak diketahui';

    return '${sw.latitude.toStringAsFixed(3)}…${ne.latitude.toStringAsFixed(3)} LU, '
        '${sw.longitude.toStringAsFixed(3)}…${ne.longitude.toStringAsFixed(3)} BT';
  }
}

/// Menyediakan basemap vektor offline untuk layar penjelajahan.
///
/// Petanya dibundel bersama aplikasi sebagai satu arsip `.pmtiles` berisi data
/// vektor Protomaps (turunan OpenStreetMap) untuk area bermain. Pilihan itu
/// diambil karena tiga hal sekaligus:
///
///  • **Tanpa kunci API dan tanpa biaya berulang.** Tidak ada server tile pihak
///    ketiga yang dihubungi, jadi tidak ada kuota yang bisa habis dan tidak ada
///    ketentuan pemakaian yang bisa dilanggar saat pemain bertambah.
///  • **Berjalan tanpa jaringan.** Halaman masjid kerap berada di balik dinding
///    tebal dengan sinyal seluler buruk. Peta yang gagal memuat di sana akan
///    menghentikan permainan tepat di saat pemain paling membutuhkannya.
///  • **Paletnya milik kita.** Karena tile-nya berisi geometri, bukan gambar,
///    tampilannya ditentukan sepenuhnya oleh `GameMapStyle`.
///
/// Cara membuat ulang arsipnya untuk masjid baru dijelaskan di
/// `assets/map/README.md`.
class BasemapService {
  /// Lokasi arsip di dalam bundel aplikasi.
  static const String assetPath = 'assets/map/basemap.pmtiles';

  /// Nama sumber pada tema. Harus sama dengan `source` di `GameMapStyle`.
  static const String sourceId = 'protomaps';

  Future<Basemap>? _pending;

  /// Memuat basemap. Hasilnya di-cache untuk seluruh umur aplikasi.
  ///
  /// Membuka arsip berarti membaca header dan direktori akarnya, sementara
  /// layar peta bisa dibangun ulang berkali-kali dalam satu sesi.
  Future<Basemap> load() => _pending ??= _open();

  Future<Basemap> _open() async {
    final File file;
    try {
      final materialized = await _materializeAsset();
      if (materialized == null) {
        return const Basemap.unavailable(
          'Berkas peta tidak ada di dalam aplikasi. '
          'Pastikan assets/map/basemap.pmtiles terdaftar di pubspec.yaml, '
          'lalu jalankan ulang aplikasi (bukan hot reload).',
        );
      }
      file = materialized;
    } on MissingPluginException {
      // Terjadi ketika path_provider baru ditambahkan lalu aplikasi hanya
      // di-hot-reload. Plugin bawaan platform hanya terdaftar saat aplikasi
      // benar-benar dijalankan ulang.
      return const Basemap.unavailable(
        'Plugin penyimpanan belum terpasang. Hentikan aplikasi sepenuhnya '
        'lalu jalankan ulang — hot reload tidak mendaftarkan plugin baru.',
      );
    } on Object catch (error, stackTrace) {
      debugPrint('BasemapService: gagal menyiapkan berkas peta — $error');
      debugPrintStack(stackTrace: stackTrace);
      return Basemap.unavailable('Berkas peta gagal disiapkan: $error');
    }

    try {
      final archive = await PmTilesArchive.from(file.path);
      final provider = PmTilesVectorTileProvider.fromArchive(archive);

      debugPrint(
        'BasemapService: basemap siap — zoom ${archive.header.minZoom}'
        '–${archive.header.maxZoom}, cakupan ${archive.header.minPosition} '
        'sampai ${archive.header.maxPosition}',
      );

      return Basemap.ready(
        providers: TileProviders({sourceId: provider}),
        southWest: archive.header.minPosition,
        northEast: archive.header.maxPosition,
      );
    } on Object catch (error, stackTrace) {
      debugPrint('BasemapService: gagal membuka arsip peta — $error');
      debugPrintStack(stackTrace: stackTrace);
      return Basemap.unavailable('Arsip peta gagal dibuka: $error');
    }
  }

  /// Menyalin arsip dari bundel aset ke direktori aplikasi, lalu memberikan
  /// berkasnya. Null bila asetnya tidak ada di dalam bundel.
  ///
  /// Penyalinan ini tidak bisa dihindari: paket `pmtiles` membaca arsip dengan
  /// pembacaan acak pada rentang byte tertentu — itulah yang membuatnya hemat —
  /// sementara aset Flutter hanya bisa dibaca utuh sekaligus. Menyalinnya sekali
  /// jauh lebih murah daripada menahan 5 MB di memori sepanjang sesi.
  Future<File?> _materializeAsset() async {
    final ByteData data;
    try {
      data = await rootBundle.load(assetPath);
    } on FlutterError {
      debugPrint(
        'BasemapService: $assetPath tidak ditemukan di dalam bundel. '
        'Lihat assets/map/README.md.',
      );
      return null;
    }

    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/basemap.pmtiles');

    // Ukuran dipakai sebagai penanda versi. Arsip yang diganti pada rilis
    // berikutnya hampir pasti berbeda ukuran, sementara membandingkan isinya
    // berarti membaca 5 MB pada setiap kali aplikasi dibuka.
    //
    // Pemeriksaannya sengaja sinkron: keduanya hanya membaca metadata berkas,
    // dan lint `avoid_slow_async_io` memang menganjurkan bentuk ini.
    if (file.existsSync() && file.lengthSync() == data.lengthInBytes) {
      return file;
    }

    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );

    return file;
  }
}
