import 'package:equatable/equatable.dart';

import 'json_utils.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    required this.totalXp,
    required this.level,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String username;
  final String fullName;
  final String role;
  final int totalXp;
  final int level;
  final String? avatarUrl;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: Json.str(json['id']),
        email: Json.str(json['email']),
        username: Json.str(json['username']),
        fullName: Json.str(json['fullName']),
        role: Json.str(json['role'], 'PLAYER'),
        totalXp: Json.integer(json['totalXp']),
        level: Json.integer(json['level'], 1),
        avatarUrl: Json.strOrNull(json['avatarUrl']),
      );

  /// Inisial untuk avatar cadangan saat pemain belum mengunggah foto.
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  List<Object?> get props =>
      [id, email, username, fullName, role, totalXp, level, avatarUrl];
}

/// Pasangan token beserta umur access token.
class AuthTokens extends Equatable {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: Json.str(json['accessToken']),
        refreshToken: Json.str(json['refreshToken']),
        expiresIn: Json.integer(json['expiresIn'], 900),
      );

  @override
  List<Object?> get props => [accessToken, refreshToken, expiresIn];
}

class AuthSession extends Equatable {
  const AuthSession({required this.user, required this.tokens});

  final User user;
  final AuthTokens tokens;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        user: User.fromJson(Json.map(json['user'])),
        tokens: AuthTokens.fromJson(Json.map(json['tokens'])),
      );

  @override
  List<Object?> get props => [user, tokens];
}

/// Rincian kemajuan level, dipakai bilah XP di layar profil.
class LevelProgress extends Equatable {
  const LevelProgress({
    required this.level,
    required this.totalXp,
    required this.xpIntoLevel,
    required this.progress,
    this.xpToNextLevel,
  });

  final int level;
  final int totalXp;
  final int xpIntoLevel;

  /// 0–1. Bernilai 1 pada level maksimum.
  final double progress;

  /// Null bila pemain sudah mencapai level maksimum.
  final int? xpToNextLevel;

  factory LevelProgress.fromJson(Map<String, dynamic> json) => LevelProgress(
        level: Json.integer(json['level'], 1),
        totalXp: Json.integer(json['totalXp']),
        xpIntoLevel: Json.integer(json['xpIntoLevel']),
        progress: Json.decimal(json['progress']).clamp(0, 1).toDouble(),
        xpToNextLevel: Json.intOrNull(json['xpToNextLevel']),
      );

  bool get isMaxLevel => xpToNextLevel == null;

  @override
  List<Object?> get props =>
      [level, totalXp, xpIntoLevel, progress, xpToNextLevel];
}

class PlayerStats extends Equatable {
  const PlayerStats({
    required this.totalXp,
    required this.levelProgress,
    required this.discoveryCount,
    required this.totalCollectibles,
    required this.completionRate,
    required this.missionsCompleted,
    required this.missionsTotal,
    required this.quizzesPassed,
    required this.perfectQuizzes,
    required this.achievementsUnlocked,
    required this.discoveriesByRarity,
    this.rank,
  });

  final int totalXp;
  final LevelProgress levelProgress;
  final int discoveryCount;
  final int totalCollectibles;
  final double completionRate;
  final int missionsCompleted;
  final int missionsTotal;
  final int quizzesPassed;
  final int perfectQuizzes;
  final int achievementsUnlocked;
  final Map<String, int> discoveriesByRarity;
  final int? rank;

  factory PlayerStats.fromJson(Map<String, dynamic> json) => PlayerStats(
        totalXp: Json.integer(json['totalXp']),
        levelProgress: LevelProgress.fromJson(Json.map(json['levelProgress'])),
        discoveryCount: Json.integer(json['discoveryCount']),
        totalCollectibles: Json.integer(json['totalCollectibles']),
        completionRate: Json.decimal(json['completionRate']),
        missionsCompleted: Json.integer(json['missionsCompleted']),
        missionsTotal: Json.integer(json['missionsTotal']),
        quizzesPassed: Json.integer(json['quizzesPassed']),
        perfectQuizzes: Json.integer(json['perfectQuizzes']),
        achievementsUnlocked: Json.integer(json['achievementsUnlocked']),
        discoveriesByRarity: Json.countMap(json['discoveriesByRarity']),
        rank: Json.intOrNull(json['rank']),
      );

  @override
  List<Object?> get props => [
        totalXp,
        levelProgress,
        discoveryCount,
        totalCollectibles,
        completionRate,
        missionsCompleted,
        missionsTotal,
        quizzesPassed,
        perfectQuizzes,
        achievementsUnlocked,
        discoveriesByRarity,
        rank,
      ];
}
