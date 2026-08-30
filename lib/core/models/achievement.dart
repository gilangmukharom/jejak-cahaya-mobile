import 'package:equatable/equatable.dart';

import 'json_utils.dart';

class Achievement extends Equatable {
  const Achievement({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.xpReward,
    required this.threshold,
    required this.currentValue,
    required this.isUnlocked,
    this.iconUrl,
    this.unlockedAt,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final int xpReward;

  /// Nilai yang harus dicapai agar pencapaian terbuka.
  final int threshold;

  /// Kemajuan pemain saat ini, sudah dibatasi agar tidak melebihi [threshold].
  final int currentValue;

  final bool isUnlocked;
  final String? iconUrl;
  final DateTime? unlockedAt;

  factory Achievement.fromJson(Map<String, dynamic> json) {
    final threshold = Json.integer(json['threshold'], 1);

    return Achievement(
      id: Json.str(json['id']),
      slug: Json.str(json['slug']),
      title: Json.str(json['title']),
      description: Json.str(json['description']),
      xpReward: Json.integer(json['xpReward']),
      threshold: threshold,
      currentValue: Json.integer(json['currentValue']),
      // Endpoint scan mengirim achievement yang baru terbuka tanpa kolom
      // `isUnlocked` — kehadirannya di sana sudah berarti terbuka.
      isUnlocked: Json.boolean(json['isUnlocked'],
          fallback: json['unlockedAt'] != null),
      iconUrl: Json.strOrNull(json['iconUrl']),
      unlockedAt: Json.dateTimeOrNull(json['unlockedAt']),
    );
  }

  double get progress =>
      threshold > 0 ? (currentValue / threshold).clamp(0, 1) : 0;

  @override
  List<Object?> get props => [id, slug, isUnlocked, currentValue];
}
