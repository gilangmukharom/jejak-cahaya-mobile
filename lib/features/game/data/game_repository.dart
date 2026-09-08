import '../../../core/constants/api_endpoints.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/models/achievement.dart';
import '../../../core/models/checkpoint.dart';
import '../../../core/models/collectible.dart';
import '../../../core/models/json_utils.dart';
import '../../../core/models/leaderboard_entry.dart';
import '../../../core/models/mission.dart';
import '../../../core/models/mosque.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/scan_result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/services/location_service.dart';

/// Seluruh operasi gameplay: masjid, checkpoint, misi, scan, koleksi, quiz,
/// papan peringkat, dan pencapaian.
///
/// Dikumpulkan dalam satu repository karena semuanya berbagi satu alur yang
/// sama dan saling merujuk — hasil scan, misalnya, langsung membawa progres
/// misi dan pencapaian yang baru terbuka. Memecahnya per endpoint akan
/// menyebarkan satu peristiwa permainan ke banyak kelas tanpa manfaat nyata.
class GameRepository {
  const GameRepository(this._api);

  final ApiClient _api;

  // ── Masjid & geofence ─────────────────────────────────────────

  /// Seluruh lokasi yang bisa dimainkan.
  ///
  /// Bila [position] dikirim, tiap lokasi dilengkapi jarak dan status
  /// di-dalam/di-luar area, dan daftarnya datang **terurut dari yang
  /// terdekat** — urutan yang berguna bagi pemain yang sedang berdiri di suatu
  /// tempat dan ingin tahu ke mana ia bisa pergi.
  ///
  /// Ketika permintaan membawa token, tiap lokasi juga membawa kemajuan pemain
  /// di lokasi itu saja, sehingga layar daftar lokasi cukup satu panggilan.
  Future<List<Mosque>> fetchMosques({PlayerPosition? position}) =>
      FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.mosques,
          queryParameters: {
            if (position != null) ...{
              'latitude': position.latitude,
              'longitude': position.longitude,
            },
          },
          parser: (data) => Json.list(data, Mosque.fromJson),
        ),
      );

  /// Lokasi terdekat dari posisi pemain.
  ///
  /// Null bila belum ada masjid sama sekali. Jarak dan status area ikut
  /// terisi, jadi jawabannya cukup untuk langsung membuka lokasi yang benar.
  Future<Mosque?> fetchNearestMosque(PlayerPosition position) =>
      FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.nearestMosque,
          queryParameters: {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
          parser: (data) =>
              data is Map<String, dynamic> ? Mosque.fromJson(data) : null,
        ),
      );

  /// Detail satu lokasi, lengkap dengan kemajuan pemain di sana.
  Future<Mosque> fetchMosque(String id, {PlayerPosition? position}) =>
      FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.mosque(id),
          queryParameters: {
            if (position != null) ...{
              'latitude': position.latitude,
              'longitude': position.longitude,
            },
          },
          parser: (data) => Mosque.fromJson(Json.map(data)),
        ),
      );

  /// Layer 1 — memeriksa apakah pemain berada di dalam area masjid.
  Future<GeofenceStatus> checkGeofence({
    required String mosqueId,
    required PlayerPosition position,
  }) =>
      FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.geofence(mosqueId),
          queryParameters: {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
          parser: (data) => GeofenceStatus.fromJson(Json.map(data)),
        ),
      );

  // ── Checkpoint ────────────────────────────────────────────────

  /// Checkpoint pada sebuah masjid.
  ///
  /// Bila [position] dikirim, tiap checkpoint dilengkapi jarak dan bearing hasil
  /// perhitungan server — dipakai peta dan radar.
  Future<List<Checkpoint>> fetchCheckpoints({
    required String mosqueId,
    PlayerPosition? position,
  }) =>
      FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.checkpoints,
          queryParameters: {
            'mosqueId': mosqueId,
            if (position != null) ...{
              'latitude': position.latitude,
              'longitude': position.longitude,
            },
          },
          parser: (data) => Json.list(data, Checkpoint.fromJson),
        ),
      );

  // ── Misi ──────────────────────────────────────────────────────

  Future<List<Mission>> fetchMissions(String mosqueId) => FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.missions,
          queryParameters: {'mosqueId': mosqueId},
          parser: (data) => Json.list(data, Mission.fromJson),
        ),
      );

  /// Misi yang sedang berjalan. Null bila seluruh misi sudah diselesaikan.
  Future<Mission?> fetchActiveMission(String mosqueId) => FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.activeMission,
          queryParameters: {'mosqueId': mosqueId},
          parser: (data) =>
              data is Map<String, dynamic> ? Mission.fromJson(data) : null,
        ),
      );

  Future<MissionDetail> fetchMissionDetail(String missionId) =>
      FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.mission(missionId),
          parser: (data) => MissionDetail.fromJson(Json.map(data)),
        ),
      );

  // ── Scan ──────────────────────────────────────────────────────

  /// Mengirim hasil pemindaian QR untuk divalidasi tiga lapis.
  ///
  /// Melempar `ServerFailure` dengan `code` yang menjelaskan lapis mana yang
  /// gagal: `OUTSIDE_GEOFENCE`, `TOO_FAR_FROM_CHECKPOINT`, `QR_SIGNATURE_INVALID`,
  /// `MOCK_LOCATION_DETECTED`, `POOR_GPS_ACCURACY`, atau `ALREADY_DISCOVERED`.
  Future<ScanResult> scan({
    required String payload,
    required PlayerPosition position,
  }) =>
      FailureMapper.guard(
        () => _api.post(
          ApiEndpoints.scan,
          body: {'payload': payload, ...position.toJson()},
          parser: (data) => ScanResult.fromJson(Json.map(data)),
        ),
      );

  /// Memeriksa apakah scan akan diterima, tanpa mengklaim penemuan.
  Future<ScanPreview> previewScan({
    required String payload,
    required PlayerPosition position,
  }) =>
      FailureMapper.guard(
        () => _api.post(
          ApiEndpoints.scanPreview,
          body: {'payload': payload, ...position.toJson()},
          parser: (data) => ScanPreview.fromJson(Json.map(data)),
        ),
      );

  // ── Koleksi & katalog ─────────────────────────────────────────

  Future<Paginated<CollectionEntry>> fetchCollection({
    int page = 1,
    int limit = 20,
    String? category,
    String? rarity,
  }) =>
      FailureMapper.guard(
        () => _api.getPaginated(
          ApiEndpoints.collection,
          queryParameters: {
            'page': page,
            'limit': limit,
            if (category != null) 'category': category,
            if (rarity != null) 'rarity': rarity,
          },
          itemParser: CollectionEntry.fromJson,
        ),
      );

  Future<CollectionProgress> fetchCollectionProgress() => FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.collectionProgress,
          parser: (data) => CollectionProgress.fromJson(Json.map(data)),
        ),
      );

  Future<Paginated<Collectible>> fetchCatalog({
    int page = 1,
    int limit = 20,
    String? search,
    String? category,
  }) =>
      FailureMapper.guard(
        () => _api.getPaginated(
          ApiEndpoints.collectibles,
          queryParameters: {
            'page': page,
            'limit': limit,
            if (search != null && search.isNotEmpty) 'search': search,
            if (category != null) 'category': category,
          },
          itemParser: Collectible.fromJson,
        ),
      );

  Future<Collectible> fetchCollectible(String idOrSlug) => FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.collectible(idOrSlug),
          parser: (data) => Collectible.fromJson(Json.map(data)),
        ),
      );

  // ── Quiz ──────────────────────────────────────────────────────

  Future<Quiz> fetchQuiz(String quizId) => FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.quiz(quizId),
          parser: (data) => Quiz.fromJson(Json.map(data)),
        ),
      );

  Future<Quiz> fetchQuizByCollectible(String collectibleId) =>
      FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.quizByCollectible(collectibleId),
          parser: (data) => Quiz.fromJson(Json.map(data)),
        ),
      );

  Future<QuizResult> submitQuiz({
    required String quizId,
    required List<QuizAnswer> answers,
    int? durationSec,
  }) =>
      FailureMapper.guard(
        () => _api.post(
          ApiEndpoints.submitQuiz(quizId),
          body: {
            'answers': answers.map((answer) => answer.toJson()).toList(),
            if (durationSec != null) 'durationSec': durationSec,
          },
          parser: (data) => QuizResult.fromJson(Json.map(data)),
        ),
      );

  // ── Peringkat & pencapaian ────────────────────────────────────

  Future<Paginated<LeaderboardEntry>> fetchLeaderboard({
    LeaderboardPeriod period = LeaderboardPeriod.all,
    int page = 1,
    int limit = 20,
  }) =>
      FailureMapper.guard(
        () => _api.getPaginated(
          ApiEndpoints.leaderboard,
          queryParameters: {
            'period': period.value,
            'page': page,
            'limit': limit
          },
          itemParser: LeaderboardEntry.fromJson,
        ),
      );

  Future<LeaderboardEntry?> fetchMyRank() => FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.myRank,
          parser: (data) => data is Map<String, dynamic>
              ? LeaderboardEntry.fromJson(data)
              : null,
        ),
      );

  Future<List<Achievement>> fetchAchievements() => FailureMapper.guard(
        () => _api.get(
          ApiEndpoints.achievements,
          parser: (data) => Json.list(data, Achievement.fromJson),
        ),
      );
}
