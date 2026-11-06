import 'package:flutter/painting.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

/// Gaya basemap permainan — palet bergaya Pokémon GO di atas data Protomaps.
///
/// Peta di layar utama bukan gambar jadi yang diunduh dari server tile,
/// melainkan digambar sendiri di perangkat dari data vektor. Berkas inilah yang
/// menentukan hasilnya: warna apa yang dipakai, dan yang jauh lebih penting,
/// **apa saja yang tidak digambar**.
///
/// Tiga keputusan yang membuatnya terasa seperti permainan, bukan seperti peta:
///
///  1. **Tanpa satu pun label.** Tidak ada nama jalan, nama tempat, atau ikon
///     POI. Sebuah layar permainan tidak boleh punya teks yang tidak bisa
///     ditindaklanjuti pemain — satu-satunya teks di atas peta adalah milik
///     kita sendiri (nomor checkpoint dan jarak). Efek sampingnya menguntungkan:
///     tanpa layer `symbol`, tidak ada berkas glyph yang perlu diunduh, jadi
///     peta ini benar-benar berjalan tanpa jaringan sama sekali.
///
///  2. **Tanah berwarna rumput, bukan kertas.** Peta konvensional memberi warna
///     terang pada yang terbangun dan warna pada yang hijau. Di sini dibalik:
///     seluruh daratan hijau, dan jalan justru menjadi jalur terang di atasnya —
///     persis logika visual peta permainan luar ruang.
///
///  3. **Garis lebih tebal dari peta biasa.** Aplikasi ini dipakai sambil
///     berjalan, dengan satu tangan, di bawah matahari. Jalan yang terbaca pada
///     peta navigasi terlalu tipis untuk dilirik sekilas.
///
/// Skema sumbernya adalah Protomaps basemap v4 (`earth`, `landuse`, `water`,
/// `roads`, `buildings`), lihat <https://docs.protomaps.com/basemaps/layers>.
class GameMapStyle {
  const GameMapStyle._();

  // ── Palet ─────────────────────────────────────────────────────
  // Dituliskan sebagai konstanta agar bisa disetel ulang di satu tempat.
  // Nuansanya sengaja digeser sedikit lebih hangat dan lebih tua daripada
  // Pokémon GO supaya duduk berdampingan dengan hijau tua & emas identitas
  // Jejak Cahaya, alih-alih bertabrakan dengannya.

  /// Rumput — warna dasar seluruh daratan.
  static const String _grass = '#a4d9a2';

  /// [_grass] dalam bentuk yang bisa dipakai widget Flutter.
  ///
  /// Dipakai sebagai latar `FlutterMap`, sehingga layar sudah berwarna rumput
  /// sebelum tile pertama selesai digambar — tanpa itu peta berkedip putih
  /// setiap kali dibuka. Nilainya harus selalu sama dengan [_grass].
  static const Color groundColor = Color(0xFFA4D9A2);

  /// Hijau yang lebih pekat: taman, hutan, pemakaman, area lindung.
  static const String _grassDeep = '#7cc586';

  /// Hijau kota yang lebih redup: pekarangan, semak, kebun.
  static const String _grassMuted = '#93d195';

  /// Air — biru toska cerah, satu-satunya warna jenuh di peta.
  static const String _water = '#54c6e6';

  /// Pasir dan pantai.
  static const String _sand = '#ecdfb8';

  /// Area pejalan kaki, alun-alun, pelataran.
  static const String _plaza = '#e6e1cf';

  /// Tapak institusi (sekolah, rumah sakit) — netral agar tidak menarik mata.
  static const String _institution = '#cfdccc';

  /// Bangunan: badan dan garis tepinya.
  ///
  /// Garis tepi yang lebih gelap inilah yang memberi kesan gambar tangan —
  /// tanpa itu bangunan hanya menjadi bercak abu-abu di atas rumput.
  static const String _building = '#e3e7dc';
  static const String _buildingEdge = '#a8bda6';

  /// Jalan. Tiap kelas punya isi terang dan bingkai (casing) lebih gelap;
  /// bingkai inilah yang membuat jalan tampak menempel di atas rumput alih-alih
  /// melayang.
  static const String _roadFill = '#fdfaf0';
  static const String _roadFillMinor = '#f7f2e4';
  static const String _roadCasing = '#cdc5ab';
  static const String _roadCasingMinor = '#d8d1ba';

  /// Jalur setapak dan gang — digambar putus-putus.
  static const String _path = '#efe8d4';

  /// Rel kereta.
  static const String _rail = '#bcc4ba';

  /// Susunan layer, dari yang paling bawah ke paling atas.
  ///
  /// Urutan di sini adalah urutan penggambaran: apa pun yang terdaftar
  /// belakangan tergambar di atas yang sebelumnya.
  static const List<Map<String, Object>> _layers = [
    // ── Dasar ─────────────────────────────────────────────────
    {
      'id': 'background',
      'type': 'background',
      'paint': {'background-color': _grass},
    },
    {
      'id': 'earth',
      'type': 'fill',
      'source': 'protomaps',
      'source-layer': 'earth',
      'paint': {'fill-color': _grass},
    },

    // ── Tata guna lahan ───────────────────────────────────────
    {
      'id': 'landuse_green_deep',
      'type': 'fill',
      'source': 'protomaps',
      'source-layer': 'landuse',
      'filter': [
        'in',
        'kind',
        'park',
        'national_park',
        'forest',
        'wood',
        'nature_reserve',
        'protected_area',
        'cemetery',
        'golf_course',
        'zoo',
      ],
      'paint': {'fill-color': _grassDeep},
    },
    {
      'id': 'landuse_green_muted',
      'type': 'fill',
      'source': 'protomaps',
      'source-layer': 'landuse',
      'filter': ['in', 'kind', 'urban_green', 'grass', 'scrub', 'farmland'],
      'paint': {'fill-color': _grassMuted},
    },
    {
      'id': 'landuse_sand',
      'type': 'fill',
      'source': 'protomaps',
      'source-layer': 'landuse',
      'filter': ['in', 'kind', 'beach', 'sand'],
      'paint': {'fill-color': _sand},
    },
    {
      'id': 'landuse_institution',
      'type': 'fill',
      'source': 'protomaps',
      'source-layer': 'landuse',
      'filter': ['in', 'kind', 'school', 'hospital', 'university'],
      'paint': {'fill-color': _institution},
    },
    {
      'id': 'landuse_plaza',
      'type': 'fill',
      'source': 'protomaps',
      'source-layer': 'landuse',
      'filter': ['in', 'kind', 'pedestrian', 'pier'],
      'paint': {'fill-color': _plaza},
    },

    // ── Air ───────────────────────────────────────────────────
    {
      'id': 'water',
      'type': 'fill',
      'source': 'protomaps',
      'source-layer': 'water',
      'paint': {'fill-color': _water},
    },
    {
      'id': 'water_stream',
      'type': 'line',
      'source': 'protomaps',
      'source-layer': 'water',
      'filter': ['in', 'kind', 'river', 'stream', 'canal'],
      'paint': {
        'line-color': _water,
        'line-width': [
          'interpolate',
          ['exponential', 1.6],
          ['zoom'],
          12,
          0.8,
          16,
          4.0,
          19,
          14.0,
        ],
      },
    },

    // ── Jalan ─────────────────────────────────────────────────
    // Bingkai seluruh kelas jalan digambar lebih dulu sebagai satu kelompok,
    // baru isinya. Kalau bingkai dan isi tiap kelas digambar berpasangan,
    // bingkai jalan besar akan menimpa isi jalan kecil di setiap persimpangan
    // dan jaringan jalannya tampak terputus-putus.
    {
      'id': 'roads_minor_casing',
      'type': 'line',
      'source': 'protomaps',
      'source-layer': 'roads',
      'filter': [
        'all',
        ['!has', 'is_tunnel'],
        ['==', 'kind', 'minor_road'],
      ],
      'paint': {
        'line-color': _roadCasingMinor,
        'line-width': [
          'interpolate',
          ['exponential', 1.6],
          ['zoom'],
          13,
          1.2,
          16,
          5.0,
          19,
          20.0,
        ],
      },
    },
    {
      'id': 'roads_major_casing',
      'type': 'line',
      'source': 'protomaps',
      'source-layer': 'roads',
      'filter': [
        'all',
        ['!has', 'is_tunnel'],
        ['in', 'kind', 'major_road', 'highway'],
      ],
      'paint': {
        'line-color': _roadCasing,
        'line-width': [
          'interpolate',
          ['exponential', 1.6],
          ['zoom'],
          12,
          2.4,
          16,
          8.0,
          19,
          30.0,
        ],
      },
    },
    {
      'id': 'roads_path',
      'type': 'line',
      'source': 'protomaps',
      'source-layer': 'roads',
      'filter': [
        'all',
        ['!has', 'is_tunnel'],
        ['in', 'kind', 'path', 'other'],
      ],
      'paint': {
        'line-color': _path,
        'line-dasharray': [2.5, 1.5],
        'line-width': [
          'interpolate',
          ['exponential', 1.6],
          ['zoom'],
          15,
          1.4,
          19,
          8.0,
        ],
      },
    },
    {
      'id': 'roads_minor',
      'type': 'line',
      'source': 'protomaps',
      'source-layer': 'roads',
      'filter': [
        'all',
        ['!has', 'is_tunnel'],
        ['==', 'kind', 'minor_road'],
      ],
      'paint': {
        'line-color': _roadFillMinor,
        'line-width': [
          'interpolate',
          ['exponential', 1.6],
          ['zoom'],
          13,
          0.4,
          16,
          3.4,
          19,
          15.0,
        ],
      },
    },
    {
      'id': 'roads_major',
      'type': 'line',
      'source': 'protomaps',
      'source-layer': 'roads',
      'filter': [
        'all',
        ['!has', 'is_tunnel'],
        ['in', 'kind', 'major_road', 'highway'],
      ],
      'paint': {
        'line-color': _roadFill,
        'line-width': [
          'interpolate',
          ['exponential', 1.6],
          ['zoom'],
          12,
          1.4,
          16,
          5.6,
          19,
          23.0,
        ],
      },
    },
    {
      'id': 'roads_rail',
      'type': 'line',
      'source': 'protomaps',
      'source-layer': 'roads',
      'filter': ['==', 'kind', 'rail'],
      'paint': {
        'line-color': _rail,
        'line-dasharray': [3.0, 2.0],
        'line-width': [
          'interpolate',
          ['exponential', 1.6],
          ['zoom'],
          14,
          0.8,
          19,
          5.0,
        ],
      },
    },

    // ── Bangunan ──────────────────────────────────────────────
    // Digambar paling akhir, di atas jalan: pemain memakai siluet bangunan
    // untuk mencocokkan apa yang dilihatnya di depan mata dengan peta, jadi
    // bangunan tidak boleh tertutup apa pun.
    {
      'id': 'buildings',
      'type': 'fill',
      'source': 'protomaps',
      'source-layer': 'buildings',
      'paint': {
        'fill-color': _building,
        'fill-outline-color': _buildingEdge,
        'fill-outline-width': 1.2,
      },
    },
  ];

  /// Membangun tema siap pakai untuk `VectorTileLayer`.
  ///
  /// Sumbernya dinamai `protomaps` agar cocok dengan kunci pada `TileProviders`
  /// yang dirakit di [BasemapService].
  static Theme build() => const ProtomapsThemes(
        sources: {
          'protomaps': {
            'type': 'vector',
            'attribution':
                '<a href="https://github.com/protomaps/basemaps">Protomaps</a> '
                    '© <a href="https://openstreetmap.org">OpenStreetMap</a>',
          },
        },
      ).build(_layers);
}
