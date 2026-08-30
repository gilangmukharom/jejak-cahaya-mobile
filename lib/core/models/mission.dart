import 'package:equatable/equatable.dart';

import 'checkpoint.dart';
import 'enums.dart';
import 'json_utils.dart';

class Mission extends Equatable {
  const Mission({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.orderIndex,
    required this.xpReward,
    required this.totalCheckpoints,
    required this.completedCheckpoints,
    required this.progress,
    this.iconUrl,
    this.completedAt,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final MissionType type;
  final MissionStatus status;
  final int orderIndex;
  final int xpReward;
  final int totalCheckpoints;
  final int completedCheckpoints;

  /// 0–1.
  final double progress;

  final String? iconUrl;
  final DateTime? completedAt;

  factory Mission.fromJson(Map<String, dynamic> json) => Mission(
        id: Json.str(json['id']),
        slug: Json.str(json['slug']),
        title: Json.str(json['title']),
        description: Json.str(json['description']),
        type: MissionType.parse(Json.strOrNull(json['type'])),
        status: MissionStatus.parse(Json.strOrNull(json['status'])),
        orderIndex: Json.integer(json['orderIndex']),
        xpReward: Json.integer(json['xpReward']),
        totalCheckpoints: Json.integer(json['totalCheckpoints']),
        completedCheckpoints: Json.integer(json['completedCheckpoints']),
        progress: Json.decimal(json['progress']).clamp(0, 1).toDouble(),
        iconUrl: Json.strOrNull(json['iconUrl']),
        completedAt: Json.dateTimeOrNull(json['completedAt']),
      );

  String get progressLabel => '$completedCheckpoints/$totalCheckpoints';

  @override
  List<Object?> get props =>
      [id, status, completedCheckpoints, totalCheckpoints];
}

/// Detail misi lengkap dengan daftar checkpoint terurut.
class MissionDetail extends Equatable {
  const MissionDetail({required this.mission, required this.checkpoints});

  final Mission mission;
  final List<MissionCheckpoint> checkpoints;

  factory MissionDetail.fromJson(Map<String, dynamic> json) => MissionDetail(
        mission: Mission.fromJson(json),
        checkpoints: Json.list(json['checkpoints'], MissionCheckpoint.fromJson),
      );

  /// Checkpoint berikutnya yang harus didatangi pemain.
  ///
  /// Pada misi berurutan ini adalah titik pertama yang belum ditemukan; pada
  /// misi bebas, titik belum ditemukan mana pun sudah cukup untuk mengarahkan.
  MissionCheckpoint? get nextCheckpoint {
    for (final checkpoint in checkpoints) {
      if (!checkpoint.isDiscovered) return checkpoint;
    }
    return null;
  }

  @override
  List<Object?> get props => [mission, checkpoints];
}

class MissionCheckpoint extends Equatable {
  const MissionCheckpoint({
    required this.id,
    required this.code,
    required this.name,
    required this.orderIndex,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isDiscovered,
    this.hint,
    this.collectiblePreview,
  });

  final String id;
  final String code;
  final String name;
  final int orderIndex;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool isDiscovered;
  final String? hint;

  /// Null selama checkpoint belum ditemukan.
  final CollectiblePreview? collectiblePreview;

  factory MissionCheckpoint.fromJson(Map<String, dynamic> json) =>
      MissionCheckpoint(
        id: Json.str(json['id']),
        code: Json.str(json['code']),
        name: Json.str(json['name']),
        orderIndex: Json.integer(json['orderIndex']),
        latitude: Json.decimal(json['latitude']),
        longitude: Json.decimal(json['longitude']),
        radiusMeters: Json.integer(json['radiusMeters'], 25),
        isDiscovered: Json.boolean(json['isDiscovered']),
        hint: Json.strOrNull(json['hint']),
        collectiblePreview: json['collectible'] is Map<String, dynamic>
            ? CollectiblePreview.fromJson(
                json['collectible'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [id, orderIndex, isDiscovered];
}
