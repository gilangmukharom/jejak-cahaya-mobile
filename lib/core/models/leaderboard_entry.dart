import 'package:equatable/equatable.dart';

import 'json_utils.dart';

class LeaderboardEntry extends Equatable {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.xp,
    required this.level,
    required this.discoveryCount,
    required this.isCurrentUser,
    this.avatarUrl,
  });

  final int rank;
  final String userId;
  final String username;
  final String fullName;
  final int xp;
  final int level;
  final int discoveryCount;

  /// True untuk baris milik pemain yang sedang login, agar bisa disorot.
  final bool isCurrentUser;

  final String? avatarUrl;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: Json.integer(json['rank']),
        userId: Json.str(json['userId']),
        username: Json.str(json['username']),
        fullName: Json.str(json['fullName']),
        xp: Json.integer(json['xp']),
        level: Json.integer(json['level'], 1),
        discoveryCount: Json.integer(json['discoveryCount']),
        isCurrentUser: Json.boolean(json['isCurrentUser']),
        avatarUrl: Json.strOrNull(json['avatarUrl']),
      );

  bool get isPodium => rank >= 1 && rank <= 3;

  @override
  List<Object?> get props => [rank, userId, xp, isCurrentUser];
}

/// Rentang waktu papan peringkat.
enum LeaderboardPeriod {
  all('all', 'Sepanjang Masa'),
  weekly('weekly', 'Minggu Ini'),
  monthly('monthly', 'Bulan Ini');

  const LeaderboardPeriod(this.value, this.label);

  final String value;
  final String label;
}
