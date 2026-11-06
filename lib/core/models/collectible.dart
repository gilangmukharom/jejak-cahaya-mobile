import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'json_utils.dart';

/// Tokoh Islam atau artefak masjid.
///
/// Backend menahan [story], [audioUrl], dan [modelUrl] sampai pemain benar-benar
/// menemukan item ini — ketiganya bernilai null pada kartu yang masih terkunci.
/// Antarmuka harus memperlakukan null di sini sebagai "belum terbuka", bukan
/// sebagai data yang hilang.
class Collectible extends Equatable {
  const Collectible({
    required this.id,
    required this.slug,
    required this.type,
    required this.category,
    required this.rarity,
    required this.name,
    required this.summary,
    required this.xpReward,
    required this.isDiscovered,
    this.title,
    this.era,
    this.region,
    this.story,
    this.imageUrl,
    this.audioUrl,
    this.modelUrl,
    this.discoveredAt,
  });

  final String id;
  final String slug;
  final CollectibleType type;
  final CollectibleCategory category;
  final Rarity rarity;
  final String name;
  final String summary;
  final int xpReward;
  final bool isDiscovered;

  final String? title;
  final String? era;
  final String? region;

  /// Kisah lengkap. Null selama item belum ditemukan.
  final String? story;

  final String? imageUrl;
  final String? audioUrl;

  /// Aset 3D untuk mode AR (Tahap 3).
  final String? modelUrl;

  final DateTime? discoveredAt;

  factory Collectible.fromJson(Map<String, dynamic> json) => Collectible(
        id: Json.str(json['id']),
        slug: Json.str(json['slug']),
        type: CollectibleType.parse(Json.strOrNull(json['type'])),
        category: CollectibleCategory.parse(Json.strOrNull(json['category'])),
        rarity: Rarity.parse(Json.strOrNull(json['rarity'])),
        name: Json.str(json['name']),
        summary: Json.str(json['summary']),
        xpReward: Json.integer(json['xpReward']),
        isDiscovered: Json.boolean(json['isDiscovered']),
        title: Json.strOrNull(json['title']),
        era: Json.strOrNull(json['era']),
        region: Json.strOrNull(json['region']),
        story: Json.strOrNull(json['story']),
        imageUrl: Json.strOrNull(json['imageUrl']),
        audioUrl: Json.strOrNull(json['audioUrl']),
        modelUrl: Json.strOrNull(json['modelUrl']),
        discoveredAt: Json.dateTimeOrNull(json['discoveredAt']),
      );

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get hasArModel => modelUrl != null && modelUrl!.isNotEmpty;

  @override
  List<Object?> get props => [id, slug, rarity, name, isDiscovered, story];
}

/// Satu entri di galeri koleksi pemain: collectible ditambah konteks penemuannya.
class CollectionEntry extends Equatable {
  const CollectionEntry({
    required this.collectible,
    required this.discoveryId,
    required this.checkpointName,
    required this.xpEarned,
  });

  final Collectible collectible;
  final String discoveryId;
  final String checkpointName;
  final int xpEarned;

  factory CollectionEntry.fromJson(Map<String, dynamic> json) =>
      CollectionEntry(
        collectible: Collectible.fromJson(json),
        discoveryId: Json.str(json['discoveryId']),
        checkpointName: Json.str(json['checkpointName']),
        xpEarned: Json.integer(json['xpEarned']),
      );

  @override
  List<Object?> get props => [discoveryId, collectible];
}

/// Ringkasan kelengkapan koleksi untuk layar galeri.
class CollectionProgress extends Equatable {
  const CollectionProgress({
    required this.owned,
    required this.total,
    required this.completionRate,
    required this.byCategory,
    required this.byRarity,
  });

  final int owned;
  final int total;
  final double completionRate;

  /// `{ kategori: (dimiliki, total) }`
  final Map<String, ProgressPair> byCategory;
  final Map<String, ProgressPair> byRarity;

  factory CollectionProgress.fromJson(Map<String, dynamic> json) =>
      CollectionProgress(
        owned: Json.integer(json['owned']),
        total: Json.integer(json['total']),
        completionRate: Json.decimal(json['completionRate']),
        byCategory: ProgressPair.parseMap(json['byCategory']),
        byRarity: ProgressPair.parseMap(json['byRarity']),
      );

  static const CollectionProgress empty = CollectionProgress(
    owned: 0,
    total: 0,
    completionRate: 0,
    byCategory: {},
    byRarity: {},
  );

  @override
  List<Object?> get props =>
      [owned, total, completionRate, byCategory, byRarity];
}

class ProgressPair extends Equatable {
  const ProgressPair({required this.owned, required this.total});

  final int owned;
  final int total;

  double get ratio => total > 0 ? owned / total : 0;
  bool get isComplete => total > 0 && owned >= total;

  static Map<String, ProgressPair> parseMap(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        entry.key.toString(): ProgressPair(
          owned: Json.integer(Json.map(entry.value)['owned']),
          total: Json.integer(Json.map(entry.value)['total']),
        ),
    };
  }

  @override
  List<Object?> get props => [owned, total];
}
