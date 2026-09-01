import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:jejak_cahaya/app/theme/game_map_style.dart';
import 'package:pmtiles/pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

/// Menguji bahwa basemap permainan benar-benar tergambar.
///
/// Uji ini ada karena satu jenis kegagalan yang sangat mudah lolos: gaya peta
/// adalah data, bukan kode. Salah tulis nama `source-layer`, atau nilai `kind`
/// yang tidak ada di skema, tidak menghasilkan galat apa pun — layernya hanya
/// diam-diam tidak menggambar apa-apa, dan peta tetap "berhasil" tampil sebagai
/// bidang hijau polos. Analyzer tidak bisa menangkapnya, dan di perangkat pun
/// tampak seperti daerah yang kebetulan lengang.
///
/// Karena itu tile sungguhan dari arsip yang dibundel digambar ke atas kanvas,
/// lalu pikselnya dihitung.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Koordinat Masjid PIK — pusat area bermain pada data seed.
  const double mosqueLat = -6.1094;
  const double mosqueLon = 106.7395;

  /// Zoom maksimum yang tersedia di dalam arsip.
  const int archiveZoom = 15;

  late PmTilesArchive archive;

  setUpAll(() async {
    archive = await PmTilesArchive.from('assets/map/basemap.pmtiles');
  });

  tearDownAll(() async => archive.close());

  test('arsip basemap mencakup lokasi masjid', () {
    expect(archive.header.maxZoom, greaterThanOrEqualTo(archiveZoom));

    final tile = _tileAt(mosqueLat, mosqueLon, archiveZoom);
    expect(
      () => ZXY(archiveZoom, tile.x, tile.y).toTileId(),
      returnsNormally,
    );
  });

  test('gaya peta menggambar jalan dan bangunan, bukan bidang kosong', () async {
    final theme = GameMapStyle.build();

    // Nama layer yang dirujuk gaya harus benar-benar ada pada tile. Ini
    // pemeriksaan yang paling langsung menangkap salah ketik `source-layer`.
    final vectorTile = await _readTile(archive, mosqueLat, mosqueLon);
    final layerNames = vectorTile.layers.map((layer) => layer.name).toSet();
    expect(
      layerNames,
      containsAll(<String>['earth', 'roads', 'buildings', 'water']),
      reason: 'skema Protomaps v4 berubah — gaya peta perlu disesuaikan',
    );

    final image = await _render(theme, vectorTile, zoom: archiveZoom.toDouble());
    // Disimpan sebelum diperiksa: uji yang gagal justru saat gambarnya paling
    // dibutuhkan untuk mencari tahu penyebabnya.
    await _dumpIfRequested(image, 'basemap_z$archiveZoom.png');

    final colors = await _distinctColors(image);

    // Bidang hijau polos hanya menghasilkan satu warna. Jalan, air, dan
    // bangunan yang tergambar pasti menambah lebih banyak dari itu.
    expect(
      colors.length,
      greaterThan(8),
      reason: 'peta tergambar nyaris polos — kemungkinan besar seluruh layer '
          'selain latar tidak terpilih oleh filternya',
    );

    // Air dan jalan diperiksa lewat sifat warnanya, bukan dengan mencocokkan
    // nilai heksadesimal dari palet. Uji ini bertugas memastikan kedua layer
    // *tergambar*, bukan mengunci warnanya — palet memang dimaksudkan untuk
    // disetel, dan uji yang gagal setiap kali warnanya digeser akan segera
    // dimatikan orang alih-alih diperbaiki.
    expect(
      colors.keys.any(_isWaterBlue),
      isTrue,
      reason: 'tidak ada piksel air — periksa filter layer `water`',
    );
    expect(
      colors.keys.any(_isRoadCream),
      isTrue,
      reason: 'tidak ada piksel jalan — periksa filter layer `roads`',
    );

    // Tidak boleh ada satu warna pun yang menguasai peta. Inilah bentuk
    // kegagalan yang paling merusak dan paling mudah lolos: satu layer dengan
    // filter terlalu longgar menutupi seluruh bidang, dan peta berubah menjadi
    // hamparan polos yang tetap "berhasil" tampil.
    final total = colors.values.reduce((a, b) => a + b);
    final dominant = colors.values.reduce(math.max);
    expect(
      dominant / total,
      lessThan(0.6),
      reason: 'satu warna menutupi hampir seluruh peta',
    );
  });

  test('gaya peta tetap menggambar saat diperbesar melewati zoom arsip',
      () async {
    // Permainan berlangsung di zoom ~18 sementara data berhenti di zoom 15.
    // Lebar garis pada gaya ditulis sebagai interpolasi terhadap zoom, jadi
    // nilai di luar rentang yang didaftarkan bisa saja menghasilkan lebar nol
    // dan membuat jalan lenyap justru pada perbesaran yang dipakai bermain.
    final theme = GameMapStyle.build();
    final vectorTile = await _readTile(archive, mosqueLat, mosqueLon);

    final image = await _render(theme, vectorTile, zoom: 18);
    await _dumpIfRequested(image, 'basemap_z18.png');

    final colors = await _distinctColors(image);

    expect(
      colors.length,
      greaterThan(8),
      reason: 'peta kosong pada zoom 18 — periksa interpolasi line-width',
    );
    expect(
      colors.keys.any(_isRoadCream),
      isTrue,
      reason: 'jalan lenyap pada zoom 18 — lebar garisnya menyusut jadi nol '
          'di luar rentang zoom yang didaftarkan pada gaya',
    );
  });
}

/// Apakah sebuah warna ARGB terbaca sebagai air.
bool _isWaterBlue(int argb) {
  final (r, g, b) = _rgb(argb);
  return b > 200 && b > r + 60 && g > r;
}

/// Apakah sebuah warna ARGB terbaca sebagai badan jalan.
bool _isRoadCream(int argb) {
  final (r, g, b) = _rgb(argb);
  return r >= 245 && g >= 238 && b >= 222 && b < r;
}

(int, int, int) _rgb(int argb) =>
    ((argb >> 16) & 0xff, (argb >> 8) & 0xff, argb & 0xff);

/// Koordinat tile slippy-map yang memuat sebuah titik.
({int x, int y}) _tileAt(double lat, double lon, int zoom) {
  final n = math.pow(2, zoom).toDouble();
  final latRad = lat * math.pi / 180;
  return (
    x: ((lon + 180) / 360 * n).floor(),
    y: ((1 - _asinh(math.tan(latRad)) / math.pi) / 2 * n).floor(),
  );
}

double _asinh(double x) => math.log(x + math.sqrt(x * x + 1));

Future<VectorTile> _readTile(
  PmTilesArchive archive,
  double lat,
  double lon,
) async {
  final coordinates = _tileAt(lat, lon, 15);
  final data = await archive.tile(
    ZXY(15, coordinates.x, coordinates.y).toTileId(),
  );
  return VectorTileReader().read(Uint8List.fromList(data.bytes()));
}

Future<ui.Image> _render(
  Theme theme,
  VectorTile vectorTile, {
  required double zoom,
}) {
  final tile = TileFactory(theme, const Logger.noop()).create(vectorTile);
  return ImageRenderer(theme: theme, scale: 2).render(
    TileSource(tileset: Tileset({'protomaps': tile})),
    zoom: zoom,
  );
}

/// Menghitung berapa piksel yang dipakai tiap warna pada gambar.
Future<Map<int, int>> _distinctColors(ui.Image image) async {
  final data = await image.toByteData();
  final counts = <int, int>{};

  // Dicuplik tiap piksel keempat pada kedua sumbu. Menghitung seluruh piksel
  // dari gambar 512×512 tidak menambah keyakinan apa pun, hanya waktu.
  for (var y = 0; y < image.height; y += 4) {
    for (var x = 0; x < image.width; x += 4) {
      final offset = (y * image.width + x) * 4;
      final r = data!.getUint8(offset);
      final g = data.getUint8(offset + 1);
      final b = data.getUint8(offset + 2);
      final a = data.getUint8(offset + 3);
      final argb = (a << 24) | (r << 16) | (g << 8) | b;
      counts[argb] = (counts[argb] ?? 0) + 1;
    }
  }

  return counts;
}

/// Menyimpan hasil render untuk diperiksa dengan mata.
///
/// Hanya berjalan bila jalur keluaran diberikan, sehingga `flutter test` biasa
/// tidak meninggalkan berkas apa pun:
///
/// ```bash
/// flutter test --dart-define=MAP_SNAPSHOT_DIR=build/map-snapshots
/// ```
Future<void> _dumpIfRequested(ui.Image image, String name) async {
  const directory = String.fromEnvironment('MAP_SNAPSHOT_DIR');
  if (directory.isEmpty) return;

  await Directory(directory).create(recursive: true);
  await File('$directory/$name').writeAsBytes(await image.toPng());
}
