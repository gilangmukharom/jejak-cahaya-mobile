import '../config/app_config.dart';

/// Menjadikan alamat aset dari backend (model 3D, dsb.) sebagai URL lengkap.
///
/// Backend menyimpan aset miliknya sendiri sebagai jalur relatif terhadap akar
/// server, mis. `/static/models/soekarno.glb`, karena alamat servernya berbeda
/// antara emulator, IP LAN, dan domain produksi — sementara nilai di database
/// harus tetap benar di ketiganya. Jalur itu diselesaikan di sini terhadap
/// [AppConfig.apiBaseUrl] yang sedang dipakai aplikasi.
///
/// Jalurnya diawali `/`, jadi bagian `/api/v1` pada alamat API ikut terganti:
/// `http://10.0.2.2:3000/api/v1` + `/static/x.glb` → `http://10.0.2.2:3000/static/x.glb`.
///
/// URL yang sudah absolut (mis. aset di CDN) dikembalikan apa adanya.
String resolveBackendAssetUrl(
  String url, {
  String apiBaseUrl = AppConfig.apiBaseUrl,
}) {
  final uri = Uri.parse(url.trim());
  if (uri.hasScheme) return uri.toString();
  return Uri.parse(apiBaseUrl).resolveUri(uri).toString();
}
