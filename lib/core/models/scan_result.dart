import 'package:equatable/equatable.dart';

import 'achievement.dart';
import 'collectible.dart';
import 'json_utils.dart';
import 'mission.dart';

/// Hasil scan QR yang berhasil — muatan untuk layar "Kamu Mendapatkan!".
class ScanResult extends Equatable {
  const ScanResult({
    required this.collectible,
    required this.checkpointName,
    required this.xpEarned,
    required this.totalXp,
    required this.hasQuiz,
    required this.missionCompleted,
    required this.unlockedAchievements,
    required this.progress,
    this.quizId,
    this.levelUp,
    this.missionProgress,
    this.nextCheckpoint,
  });

  final Collectible collectible;
  final String checkpointName;
  final int xpEarned;
  final int totalXp;
  final bool hasQuiz;
  final bool missionCompleted;
  final List<Achievement> unlockedAchievements;

  final String? quizId;

  /// Terisi hanya bila level pemain naik akibat scan ini.
  final LevelUp? levelUp;

  final Mission? missionProgress;

  /// Berapa titik sudah ditemukan dari total keseluruhan.
  final ({int discovered, int total}) progress;

  /// Titik berikutnya pada rantai main. Null bila semuanya sudah ditemukan.
  final NextCheckpoint? nextCheckpoint;

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final discovery = Json.map(json['discovery']);
    final checkpoint = Json.map(json['checkpoint']);
    final progress = Json.map(json['progress']);

    return ScanResult(
      collectible: Collectible.fromJson(Json.map(json['collectible'])),
      checkpointName: Json.str(checkpoint['name']),
      xpEarned: Json.integer(discovery['xpEarned']),
      totalXp: Json.integer(json['totalXp']),
      hasQuiz: Json.boolean(json['hasQuiz']),
      missionCompleted: Json.boolean(json['missionCompleted']),
      unlockedAchievements:
          Json.list(json['unlockedAchievements'], Achievement.fromJson),
      quizId: Json.strOrNull(json['quizId']),
      levelUp: json['levelUp'] is Map<String, dynamic>
          ? LevelUp.fromJson(json['levelUp'] as Map<String, dynamic>)
          : null,
      missionProgress: json['missionProgress'] is Map<String, dynamic>
          ? Mission.fromJson(json['missionProgress'] as Map<String, dynamic>)
          : null,
      progress: (
        discovered: Json.integer(progress['discovered']),
        total: Json.integer(progress['total']),
      ),
      nextCheckpoint: json['nextCheckpoint'] is Map<String, dynamic>
          ? NextCheckpoint.fromJson(
              json['nextCheckpoint'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [collectible, xpEarned, levelUp, missionCompleted];
}

/// Titik berikutnya yang harus didatangi pemain.
///
/// Nama tokohnya sengaja tidak disertakan backend — yang diungkap hanya lokasi
/// fisiknya, karena mengetahui tokoh sebelum menemukannya menghilangkan inti
/// permainan.
class NextCheckpoint extends Equatable {
  const NextCheckpoint({
    required this.code,
    required this.name,
    required this.playOrder,
    required this.missionTitle,
    this.hint,
  });

  final String code;
  final String name;

  /// Posisi pada rantai main 1→N, bukan urutan kode checkpoint.
  final int playOrder;
  final String missionTitle;
  final String? hint;

  factory NextCheckpoint.fromJson(Map<String, dynamic> json) => NextCheckpoint(
        code: Json.str(json['code']),
        name: Json.str(json['name']),
        playOrder: Json.integer(json['playOrder']),
        missionTitle: Json.str(json['missionTitle']),
        hint: Json.strOrNull(json['hint']),
      );

  @override
  List<Object?> get props => [code, name, playOrder, missionTitle, hint];
}

class LevelUp extends Equatable {
  const LevelUp({required this.from, required this.to});

  final int from;
  final int to;

  factory LevelUp.fromJson(Map<String, dynamic> json) => LevelUp(
        from: Json.integer(json['from']),
        to: Json.integer(json['to']),
      );

  @override
  List<Object?> get props => [from, to];
}

/// Hasil `POST /scan/preview`: apakah scan akan diterima, tanpa mengklaim apa pun.
///
/// Dipakai layar kamera untuk memberi umpan balik langsung ("dekati 8 m lagi")
/// tanpa memaksa pemain memindai berulang kali dan menabrak batas laju.
class ScanPreview extends Equatable {
  const ScanPreview({
    required this.wouldSucceed,
    this.reason,
    this.distanceM,
    this.requiredDistanceM,
  });

  final bool wouldSucceed;
  final String? reason;
  final double? distanceM;
  final double? requiredDistanceM;

  factory ScanPreview.fromJson(Map<String, dynamic> json) => ScanPreview(
        wouldSucceed: Json.boolean(json['wouldSucceed']),
        reason: Json.strOrNull(json['reason']),
        distanceM: Json.doubleOrNull(json['distanceM']),
        requiredDistanceM: Json.doubleOrNull(json['requiredDistanceM']),
      );

  /// Sisa jarak yang harus ditempuh agar scan diterima, dalam meter.
  double? get metersRemaining {
    final distance = distanceM;
    final required = requiredDistanceM;
    if (distance == null || required == null) return null;
    return (distance - required).clamp(0, double.infinity);
  }

  @override
  List<Object?> get props =>
      [wouldSucceed, reason, distanceM, requiredDistanceM];
}
