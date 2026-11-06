import 'package:equatable/equatable.dart';

import 'json_utils.dart';

/// Kemajuan pemain **pada satu lokasi**.
///
/// Sengaja per lokasi, bukan gabungan seluruh aplikasi. Begitu permainan
/// berjalan di lebih dari satu masjid, angka gabungan berhenti menjawab
/// pertanyaan yang benar-benar dimiliki pemain — "berapa lagi yang tersisa
/// *di sini*" — dan justru mengecil sendiri setiap kali kurator menambahkan
/// lokasi baru yang belum pernah ia datangi.
///
/// Null ketika permintaannya tidak membawa token; layar daftar lokasi tetap
/// bisa digambar untuk tamu, hanya tanpa angka kemajuan.
class MosqueProgress extends Equatable {
  const MosqueProgress({
    required this.totalCheckpoints,
    required this.discoveredCheckpoints,
    required this.totalMissions,
    required this.completedMissions,
    required this.xpEarned,
    required this.percent,
    required this.isCompleted,
  });

  final int totalCheckpoints;
  final int discoveredCheckpoints;
  final int totalMissions;
  final int completedMissions;

  /// XP yang benar-benar diperoleh dari penemuan di lokasi ini.
  final int xpEarned;

  /// 0–100, dibulatkan di server.
  final int percent;

  /// True bila seluruh checkpoint di lokasi ini sudah ditemukan.
  final bool isCompleted;

  /// Pecahan 0–1 untuk bilah dan cincin progres.
  double get fraction => (percent / 100).clamp(0, 1);

  bool get isUntouched => discoveredCheckpoints == 0;

  int get remainingCheckpoints =>
      (totalCheckpoints - discoveredCheckpoints).clamp(0, totalCheckpoints);

  factory MosqueProgress.fromJson(Map<String, dynamic> json) => MosqueProgress(
        totalCheckpoints: Json.integer(json['totalCheckpoints'], 0),
        discoveredCheckpoints: Json.integer(json['discoveredCheckpoints'], 0),
        totalMissions: Json.integer(json['totalMissions'], 0),
        completedMissions: Json.integer(json['completedMissions'], 0),
        xpEarned: Json.integer(json['xpEarned'], 0),
        percent: Json.integer(json['percent'], 0),
        isCompleted: Json.boolean(json['isCompleted']),
      );

  @override
  List<Object?> get props => [
        totalCheckpoints,
        discoveredCheckpoints,
        totalMissions,
        completedMissions,
        xpEarned,
        percent,
        isCompleted,
      ];
}

class Mosque extends Equatable {
  const Mosque({
    required this.id,
    required this.slug,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.description,
    this.address,
    this.city,
    this.coverImageUrl,
    this.checkpointCount = 0,
    this.missionCount = 0,
    this.distanceM,
    this.metersToEnter,
    this.isInside,
    this.progress,
  });

  final String id;
  final String slug;
  final String name;
  final double latitude;
  final double longitude;

  /// Radius geofence (Layer 1). Permainan terkunci di luar radius ini.
  final int radiusMeters;

  final String? description;
  final String? address;
  final String? city;
  final String? coverImageUrl;

  /// Jumlah titik & misi aktif di lokasi ini — terisi walau pemain belum login.
  final int checkpointCount;
  final int missionCount;

  /// Jarak ke titik pusat, meter. Null bila koordinat pemain tidak dikirim.
  final double? distanceM;

  /// Sisa jarak sampai masuk area bermain, meter.
  final double? metersToEnter;

  /// Apakah pemain sedang berada di dalam areanya. Null bila jarak tak diketahui.
  final bool? isInside;

  /// Kemajuan pemain di lokasi ini. Null untuk tamu yang belum login.
  final MosqueProgress? progress;

  /// Alamat ringkas untuk kartu — kota bila ada, jatuh ke alamat lalu slug.
  String get placeLabel => city ?? address ?? slug;

  factory Mosque.fromJson(Map<String, dynamic> json) => Mosque(
        id: Json.str(json['id']),
        slug: Json.str(json['slug']),
        name: Json.str(json['name']),
        latitude: Json.decimal(json['latitude']),
        longitude: Json.decimal(json['longitude']),
        radiusMeters: Json.integer(json['radiusMeters'], 250),
        description: Json.strOrNull(json['description']),
        address: Json.strOrNull(json['address']),
        city: Json.strOrNull(json['city']),
        coverImageUrl: Json.strOrNull(json['coverImageUrl']),
        checkpointCount: Json.integer(json['checkpointCount'], 0),
        missionCount: Json.integer(json['missionCount'], 0),
        // Ketiganya hanya dikirim server bila koordinat pemain ikut dalam
        // permintaan, jadi ketiadaannya bukan galat — hanya berarti jaraknya
        // belum diketahui, dan kartu lokasi menyembunyikan barisnya.
        distanceM:
            json['distanceM'] == null ? null : Json.decimal(json['distanceM']),
        metersToEnter: json['metersToEnter'] == null
            ? null
            : Json.decimal(json['metersToEnter']),
        isInside:
            json['isInside'] == null ? null : Json.boolean(json['isInside']),
        progress: json['progress'] == null
            ? null
            : MosqueProgress.fromJson(Json.map(json['progress'])),
      );

  /// Salinan dengan jarak yang dihitung ulang di perangkat.
  ///
  /// Dipakai saat pemain bergerak: menghitung sendiri membuat angka jarak
  /// merapat mengikuti langkah, alih-alih melompat setiap kali server sempat
  /// ditanya. Rumusnya sama dengan yang dipakai server, jadi tidak akan
  /// berselisih dengan jawaban resminya.
  Mosque withDistance(double meters) => Mosque(
        id: id,
        slug: slug,
        name: name,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        description: description,
        address: address,
        city: city,
        coverImageUrl: coverImageUrl,
        checkpointCount: checkpointCount,
        missionCount: missionCount,
        distanceM: meters,
        metersToEnter: (meters - radiusMeters).clamp(0, double.infinity),
        isInside: meters <= radiusMeters,
        progress: progress,
      );

  @override
  List<Object?> get props => [
        id,
        slug,
        name,
        latitude,
        longitude,
        radiusMeters,
        checkpointCount,
        missionCount,
        distanceM,
        isInside,
        progress,
      ];
}

/// Hasil pemeriksaan geofence — penentu apakah layar permainan terbuka.
class GeofenceStatus extends Equatable {
  const GeofenceStatus({
    required this.isInside,
    required this.distanceM,
    required this.radiusMeters,
    required this.mosque,
  });

  final bool isInside;

  /// Jarak sebenarnya ke pusat masjid, dalam meter.
  final double distanceM;
  final int radiusMeters;
  final Mosque mosque;

  factory GeofenceStatus.fromJson(Map<String, dynamic> json) => GeofenceStatus(
        isInside: Json.boolean(json['isInside']),
        distanceM: Json.decimal(json['distanceM']),
        radiusMeters: Json.integer(json['radiusMeters'], 250),
        mosque: Mosque.fromJson(Json.map(json['mosque'])),
      );

  /// Berapa jauh lagi pemain harus berjalan agar masuk area, dalam meter.
  double get metersToEnter =>
      (distanceM - radiusMeters).clamp(0, double.infinity);

  @override
  List<Object?> get props => [isInside, distanceM, radiusMeters, mosque];
}
