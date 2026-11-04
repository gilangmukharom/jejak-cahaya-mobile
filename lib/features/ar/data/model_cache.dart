import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/asset_url.dart';

/// Mengunduh model 3D tokoh sekali, lalu menyimpannya di perangkat.
///
/// Model GLB berukuran puluhan MB. Diunduh di sini — bukan oleh mesin AR atau
/// WebView-nya — karena tiga alasan:
/// - kemajuan unduhan bisa digambar sendiri, sehingga pemain yang berdiri di
///   checkpoint tahu aplikasinya sedang bekerja, bukan macet;
/// - satu berkas yang sama dipakai AR native maupun penampil 3D cadangan;
/// - membuka tokoh yang sama kedua kalinya tidak mengunduh ulang.
///
/// Kunci cache adalah alamat modelnya. Saat model di server diganti, beri nama
/// berkas baru (mis. `bilal-v2.glb`) agar perangkat tidak memakai salinan lama.
class ModelCache {
  ModelCache({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                // Bukan batas total unduhan, melainkan jeda terlama tanpa satu
                // byte pun — sinyal di area masjid bisa lambat, tetapi jalan.
                receiveTimeout: const Duration(seconds: 45),
              ),
            );

  final Dio _dio;

  /// Unduhan yang sedang berjalan, agar dua layar yang meminta model yang
  /// sama tidak mengunduhnya dua kali sekaligus.
  final Map<String, Future<File>> _inFlight = {};

  /// Berkas lokal untuk [modelUrl]; diunduh bila belum ada.
  ///
  /// [onProgress] menerima 0…1, atau null bila server tidak menyebut ukuran.
  Future<File> obtain(
    String modelUrl, {
    void Function(double? progress)? onProgress,
  }) {
    final url = resolveBackendAssetUrl(modelUrl);
    return _inFlight[url] ??= _obtain(url, onProgress).whenComplete(
      () => _inFlight.remove(url),
    );
  }

  /// Membuang salinan lokal, mis. setelah berkasnya ternyata tidak terbaca.
  Future<void> evict(String modelUrl) async {
    final file = await _fileFor(resolveBackendAssetUrl(modelUrl));
    if (file.existsSync()) await file.delete();
  }

  Future<File> _obtain(
    String url,
    void Function(double? progress)? onProgress,
  ) async {
    final target = await _fileFor(url);
    if (target.existsSync() && await _looksLikeGlb(target)) return target;

    final partial = File('${target.path}.part');
    try {
      await _dio.download(
        url,
        partial.path,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          onProgress?.call(total > 0 ? received / total : null);
        },
      );

      // Proxy atau portal Wi-Fi masjid bisa menjawab 200 dengan halaman HTML.
      // Tanpa pemeriksaan ini halaman itu tersimpan sebagai "model" dan setiap
      // percobaan berikutnya gagal tanpa pernah mengunduh ulang.
      if (!await _looksLikeGlb(partial)) {
        throw const FormatException('Berkas yang diterima bukan model GLB.');
      }

      if (target.existsSync()) await target.delete();
      return await partial.rename(target.path);
    } on Object {
      if (partial.existsSync()) await partial.delete();
      rethrow;
    }
  }

  Future<File> _fileFor(String url) async {
    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}/models');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final uri = Uri.parse(url);
    final name = '${uri.host}_${uri.port}${uri.path}'
        .replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    return File('${dir.path}/$name');
  }

  /// GLB selalu diawali empat byte ASCII `glTF`.
  static Future<bool> _looksLikeGlb(File file) async {
    try {
      final handle = await file.open();
      try {
        final header = await handle.read(4);
        return header.length == 4 &&
            header[0] == 0x67 &&
            header[1] == 0x6C &&
            header[2] == 0x54 &&
            header[3] == 0x46;
      } finally {
        await handle.close();
      }
    } on FileSystemException {
      return false;
    }
  }
}
