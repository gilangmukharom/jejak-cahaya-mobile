import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'json_utils.dart';

/// Titik QR di area masjid.
///
/// [distanceM], [bearingDeg], dan [isInRange] dihitung server ketika koordinat
/// pemain disertakan pada permintaan. Aplikasi memakai nilai-nilai itu apa
/// adanya, sehingga indikator "sudah dekat" di layar selalu sepakat dengan
/// keputusan yang nanti diambil endpoint scan.
class Checkpoint extends Equatable {
  const Checkpoint({
    required this.id,
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isDiscovered,
    required this.collectiblePreview,
    this.hint,
    this.distanceM,
    this.bearingDeg,
    this.isInRange,
  });

  final String id;
  final String code;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool isDiscovered;
  final CollectiblePreview collectiblePreview;

  final String? hint;
  final double? distanceM;
  final double? bearingDeg;
  final bool? isInRange;

  factory Checkpoint.fromJson(Map<String, dynamic> json) => Checkpoint(
        id: Json.str(json['id']),
        code: Json.str(json['code']),
        name: Json.str(json['name']),
        latitude: Json.decimal(json['latitude']),
        longitude: Json.decimal(json['longitude']),
        radiusMeters: Json.integer(json['radiusMeters'], 25),
        isDiscovered: Json.boolean(json['isDiscovered']),
        collectiblePreview:
            CollectiblePreview.fromJson(Json.map(json['collectible'])),
        hint: Json.strOrNull(json['hint']),
        distanceM: Json.doubleOrNull(json['distanceM']),
        bearingDeg: Json.doubleOrNull(json['bearingDeg']),
        isInRange: json['isInRange'] is bool ? json['isInRange'] as bool : null,
      );

  /// Jarak dalam bentuk yang mudah dibaca: "12 m" atau "1,3 km".
  String get distanceLabel {
    final distance = distanceM;
    if (distance == null) return '—';
    if (distance < 1000) return '${distance.round()} m';
    return '${(distance / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  @override
  List<Object?> get props => [id, code, isDiscovered, distanceM, isInRange];
}

/// Pratinjau collectible pada sebuah checkpoint.
///
/// Sebelum ditemukan, backend menyembunyikan nama dan gambarnya — kartu di peta
/// tampil sebagai siluet. Yang tetap dikirim hanyalah rarity, agar pemain bisa
/// melihat betapa berharganya titik yang belum mereka datangi.
class CollectiblePreview extends Equatable {
  const CollectiblePreview({
    required this.id,
    required this.name,
    required this.rarity,
    required this.isRevealed,
    this.imageUrl,
  });

  final String id;
  final String name;
  final Rarity rarity;
  final bool isRevealed;
  final String? imageUrl;

  factory CollectiblePreview.fromJson(Map<String, dynamic> json) =>
      CollectiblePreview(
        id: Json.str(json['id']),
        name: Json.str(json['name'], 'Belum ditemukan'),
        rarity: Rarity.parse(Json.strOrNull(json['rarity'])),
        isRevealed: Json.boolean(json['isRevealed']),
        imageUrl: Json.strOrNull(json['imageUrl']),
      );

  @override
  List<Object?> get props => [id, name, rarity, isRevealed];
}
