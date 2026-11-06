/// Jalur endpoint API, relatif terhadap [AppConfig.apiBaseUrl].
///
/// Dikumpulkan di satu tempat agar perubahan kontrak backend tidak perlu
/// diburu satu per satu di seluruh berkas data source.
class ApiEndpoints {
  const ApiEndpoints._();

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String changePassword = '/auth/change-password';

  // User
  static const String me = '/users/me';
  static const String myStats = '/users/me/stats';
  static const String myXpHistory = '/users/me/xp-history';

  // Masjid / lokasi permainan
  static const String mosques = '/mosques';

  /// Lokasi terdekat dari posisi pemain — dipakai untuk memilih sendiri
  /// masjid mana yang dibuka, tanpa meminta pemain memilih apa pun.
  static const String nearestMosque = '/mosques/nearest';

  static String mosque(String id) => '/mosques/$id';
  static String geofence(String id) => '/mosques/$id/geofence';

  // Checkpoint
  static const String checkpoints = '/checkpoints';
  static String checkpoint(String id) => '/checkpoints/$id';

  // Katalog
  static const String collectibles = '/collectibles';
  static const String collectibleSummary = '/collectibles/summary';
  static String collectible(String idOrSlug) => '/collectibles/$idOrSlug';

  // Misi
  static const String missions = '/missions';
  static const String activeMission = '/missions/active';
  static String mission(String id) => '/missions/$id';

  // Scan
  static const String scan = '/scan';
  static const String scanPreview = '/scan/preview';

  // Koleksi
  static const String collection = '/collection';
  static const String collectionProgress = '/collection/progress';

  // Quiz
  static String quiz(String id) => '/quizzes/$id';
  static String quizByCollectible(String collectibleId) =>
      '/quizzes/by-collectible/$collectibleId';
  static String submitQuiz(String id) => '/quizzes/$id/submit';
  static String quizAttempts(String id) => '/quizzes/$id/attempts';

  // Lainnya
  static const String leaderboard = '/leaderboard';
  static const String myRank = '/leaderboard/me';
  static const String achievements = '/achievements';
  static const String health = '/health';
}
