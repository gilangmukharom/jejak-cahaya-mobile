import 'package:equatable/equatable.dart';

import 'json_utils.dart';

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
  });

  final String id;
  final String slug;
  final String name;
  final double latitude;
  final double longitude;

  /// Radius geofence (Layer 1). Aplikasi terkunci di luar radius ini.
  final int radiusMeters;

  final String? description;
  final String? address;
  final String? city;
  final String? coverImageUrl;

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
      );

  @override
  List<Object?> get props =>
      [id, slug, name, latitude, longitude, radiusMeters];
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
