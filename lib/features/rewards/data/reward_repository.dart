import '../../../core/constants/api_endpoints.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/models/challenge.dart';
import '../../../core/models/json_utils.dart';
import '../../../core/models/reward.dart';
import '../../../core/network/api_client.dart';

/// Akses ke Reward Store: katalog, penukaran, dan riwayat NUSA POINTS.
class RewardRepository {
  const RewardRepository(this._api);

  final ApiClient _api;

  Future<RewardCatalog> fetchCatalog() => FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.rewards,
          parser: (data) => RewardCatalog.fromJson(Json.map(data)),
        ),
      );

  Future<RedeemResult> redeem(String rewardId) => FailureMapper.guard(
        () => _api.post(
          ApiEndpoints.redeemReward(rewardId),
          parser: (data) => RedeemResult.fromJson(Json.map(data)),
        ),
      );

  Future<List<Redemption>> fetchMyRedemptions() => FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.myRedemptions,
          parser: (data) => Json.list(data, Redemption.fromJson),
        ),
      );

  Future<List<Challenge>> fetchChallenges() => FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.challenges,
          parser: (data) => Json.list(data, Challenge.fromJson),
        ),
      );

  /// Mengklaim hadiah tantangan; mengembalikan poin yang diperoleh.
  Future<int> claimChallenge(String id) => FailureMapper.guard(
        () => _api.post(
          ApiEndpoints.claimChallenge(id),
          parser: (data) => Json.integer(Json.map(data)['pointsEarned']),
        ),
      );

  Future<({int balance, List<PointEntry> entries})> fetchPointHistory() =>
      FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.pointHistory,
          parser: (data) {
            final json = Json.map(data);
            return (
              balance: Json.integer(json['balance']),
              entries: Json.list(json['transactions'], PointEntry.fromJson),
            );
          },
        ),
      );
}
