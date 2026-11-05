import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'json_utils.dart';

/// Kategori hadiah di Reward Store.
enum RewardCategory {
  merchandise('MERCHANDISE', 'Merchandise', Icons.checkroom_rounded),
  voucher('VOUCHER', 'Voucher', Icons.confirmation_number_rounded),
  ticket('TICKET', 'Tiket', Icons.local_activity_rounded),
  digital('DIGITAL', 'Item Digital', Icons.auto_awesome_rounded);

  const RewardCategory(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static RewardCategory parse(String? value) =>
      RewardCategory.values.firstWhere(
        (item) => item.value == value,
        orElse: () => RewardCategory.merchandise,
      );
}

/// Satu hadiah yang bisa ditukar dengan NUSA POINTS.
class Reward extends Equatable {
  const Reward({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.pointsCost,
    required this.isAvailable,
    this.stock,
    this.imageUrl,
    this.howToClaim,
  });

  final String id;
  final String name;
  final String description;
  final RewardCategory category;
  final int pointsCost;

  /// Null = tidak terbatas.
  final int? stock;

  /// Aktif dan stoknya masih ada.
  final bool isAvailable;
  final String? imageUrl;
  final String? howToClaim;

  bool get isOutOfStock => stock != null && stock! <= 0;

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
        id: Json.str(json['id']),
        name: Json.str(json['name']),
        description: Json.str(json['description']),
        category: RewardCategory.parse(Json.strOrNull(json['category'])),
        pointsCost: Json.integer(json['pointsCost']),
        stock: Json.intOrNull(json['stock']),
        isAvailable: Json.boolean(json['isAvailable']),
        imageUrl: Json.strOrNull(json['imageUrl']),
        howToClaim: Json.strOrNull(json['howToClaim']),
      );

  @override
  List<Object?> get props => [id, pointsCost, stock, isAvailable];
}

/// Katalog Reward Store beserta saldo pemain saat itu.
class RewardCatalog extends Equatable {
  const RewardCatalog({required this.balance, required this.rewards});

  final int balance;
  final List<Reward> rewards;

  factory RewardCatalog.fromJson(Map<String, dynamic> json) => RewardCatalog(
        balance: Json.integer(json['balance']),
        rewards: Json.list(json['rewards'], Reward.fromJson),
      );

  @override
  List<Object?> get props => [balance, rewards];
}

enum RedemptionStatus {
  pending('PENDING', 'Siap diambil'),
  fulfilled('FULFILLED', 'Sudah diambil'),
  cancelled('CANCELLED', 'Dibatalkan');

  const RedemptionStatus(this.value, this.label);

  final String value;
  final String label;

  static RedemptionStatus parse(String? value) =>
      RedemptionStatus.values.firstWhere(
        (item) => item.value == value,
        orElse: () => RedemptionStatus.pending,
      );
}

/// Satu penukaran — kode yang ditunjukkan pemain ke petugas.
class Redemption extends Equatable {
  const Redemption({
    required this.id,
    required this.code,
    required this.status,
    required this.pointsSpent,
    required this.createdAt,
    required this.rewardName,
    required this.rewardCategory,
    this.howToClaim,
    this.note,
  });

  final String id;
  final String code;
  final RedemptionStatus status;
  final int pointsSpent;
  final DateTime createdAt;
  final String rewardName;
  final RewardCategory rewardCategory;
  final String? howToClaim;
  final String? note;

  factory Redemption.fromJson(Map<String, dynamic> json) {
    final reward = Json.map(json['reward']);
    return Redemption(
      id: Json.str(json['id']),
      code: Json.str(json['code']),
      status: RedemptionStatus.parse(Json.strOrNull(json['status'])),
      pointsSpent: Json.integer(json['pointsSpent']),
      createdAt: Json.dateTime(json['createdAt']),
      rewardName: Json.str(reward['name']),
      rewardCategory: RewardCategory.parse(Json.strOrNull(reward['category'])),
      howToClaim: Json.strOrNull(reward['howToClaim']),
      note: Json.strOrNull(json['note']),
    );
  }

  @override
  List<Object?> get props => [id, status];
}

/// Hasil penukaran: penukaran baru dan saldo setelahnya.
class RedeemResult {
  const RedeemResult({required this.redemption, required this.balance});

  final Redemption redemption;
  final int balance;

  factory RedeemResult.fromJson(Map<String, dynamic> json) => RedeemResult(
        redemption: Redemption.fromJson(Json.map(json['redemption'])),
        balance: Json.integer(json['balance']),
      );
}

/// Satu baris riwayat NUSA POINTS.
class PointEntry extends Equatable {
  const PointEntry({
    required this.id,
    required this.amount,
    required this.source,
    required this.createdAt,
    this.note,
  });

  final String id;

  /// Positif = bertambah, negatif = dipakai.
  final int amount;
  final String source;
  final DateTime createdAt;
  final String? note;

  factory PointEntry.fromJson(Map<String, dynamic> json) => PointEntry(
        id: Json.str(json['id']),
        amount: Json.integer(json['amount']),
        source: Json.str(json['source']),
        createdAt: Json.dateTime(json['createdAt']),
        note: Json.strOrNull(json['note']),
      );

  @override
  List<Object?> get props => [id];
}
