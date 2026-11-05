import 'package:equatable/equatable.dart';

import 'json_utils.dart';

enum ChallengePeriod {
  daily('DAILY', 'Harian'),
  weekly('WEEKLY', 'Mingguan');

  const ChallengePeriod(this.value, this.label);

  final String value;
  final String label;

  static ChallengePeriod parse(String? value) =>
      value == 'WEEKLY' ? ChallengePeriod.weekly : ChallengePeriod.daily;
}

/// Titik hero tempat sebuah tantangan "Jejak Hero" berlaku.
class ChallengeCheckpoint extends Equatable {
  const ChallengeCheckpoint({
    required this.id,
    required this.code,
    required this.name,
    required this.siteId,
    required this.siteName,
    required this.collectibleId,
    required this.collectibleName,
    required this.rarity,
  });

  final String id;
  final String code;
  final String name;
  final String siteId;
  final String siteName;
  final String collectibleId;
  final String collectibleName;

  /// Nilai enum backend: `COMMON`, `RARE`, `EPIC`, `LEGENDARY`.
  final String rarity;

  factory ChallengeCheckpoint.fromJson(Map<String, dynamic> json) =>
      ChallengeCheckpoint(
        id: Json.str(json['id']),
        code: Json.str(json['code']),
        name: Json.str(json['name']),
        siteId: Json.str(json['siteId']),
        siteName: Json.str(json['siteName']),
        collectibleId: Json.str(json['collectibleId']),
        collectibleName: Json.str(json['collectibleName']),
        rarity: Json.str(json['rarity'], 'COMMON'),
      );

  @override
  List<Object?> get props => [id];
}

/// Langkah tantangan titik. [quizPassed] null = titiknya belum punya kuis.
class ChallengeSteps extends Equatable {
  const ChallengeSteps({required this.visited, required this.quizPassed});

  final bool visited;
  final bool? quizPassed;

  factory ChallengeSteps.fromJson(Map<String, dynamic> json) => ChallengeSteps(
        visited: Json.boolean(json['visited']),
        quizPassed: json['quizPassed'] == null
            ? null
            : Json.boolean(json['quizPassed']),
      );

  @override
  List<Object?> get props => [visited, quizPassed];
}

/// Tantangan harian / mingguan beserta kemajuan pemain di periode berjalan.
///
/// Tantangan umum berlaku di mana saja; tantangan titik ([checkpoint] terisi)
/// berlaku untuk satu titik hero: pindai QR-nya lalu lulus kuisnya.
class Challenge extends Equatable {
  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.period,
    required this.target,
    required this.progress,
    required this.pointsReward,
    required this.xpReward,
    required this.isComplete,
    required this.isClaimed,
    required this.endsAt,
    this.checkpoint,
    this.steps,
  });

  final String id;
  final String title;
  final String description;
  final ChallengePeriod period;
  final int target;
  final int progress;
  final int pointsReward;
  final int xpReward;
  final bool isComplete;
  final bool isClaimed;

  /// Kapan periode ini berakhir; tantangan dimulai ulang setelahnya.
  final DateTime endsAt;

  /// Terisi hanya untuk tantangan titik.
  final ChallengeCheckpoint? checkpoint;
  final ChallengeSteps? steps;

  bool get isCheckpoint => checkpoint != null;
  bool get canClaim => isComplete && !isClaimed;
  double get ratio => target > 0 ? (progress / target).clamp(0, 1) : 0;

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        id: Json.str(json['id']),
        title: Json.str(json['title']),
        description: Json.str(json['description']),
        period: ChallengePeriod.parse(Json.strOrNull(json['period'])),
        target: Json.integer(json['target'], 1),
        progress: Json.integer(json['progress']),
        pointsReward: Json.integer(json['pointsReward']),
        xpReward: Json.integer(json['xpReward']),
        isComplete: Json.boolean(json['isComplete']),
        isClaimed: Json.boolean(json['isClaimed']),
        endsAt: Json.dateTime(json['endsAt']),
        checkpoint: json['checkpoint'] is Map<String, dynamic>
            ? ChallengeCheckpoint.fromJson(
                json['checkpoint'] as Map<String, dynamic>)
            : null,
        steps: json['steps'] is Map<String, dynamic>
            ? ChallengeSteps.fromJson(json['steps'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [id, progress, isClaimed, steps];
}
