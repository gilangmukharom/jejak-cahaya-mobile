/// Nama dan jalur rute, dikumpulkan agar navigasi tidak memakai string lepas
/// yang mudah salah ketik dan tidak terdeteksi kompiler.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  /// Gerbang geofence — layar yang menentukan permainan terbuka atau terkunci.
  static const String gate = '/gate';

  // Cangkang navigasi bawah
  static const String explore = '/explore';
  static const String collection = '/collection';
  static const String missions = '/missions';
  static const String profile = '/profile';

  static const String scanner = '/scan';
  static const String leaderboard = '/leaderboard';
  static const String achievements = '/achievements';

  static const String discoveryResult = '/discovery';
  static String collectibleDetail(String idOrSlug) => '/collectible/$idOrSlug';
  static String missionDetail(String id) => '/missions/$id';
  static String quiz(String quizId) => '/quiz/$quizId';

  /// Membuka quiz lewat tokohnya, dipakai halaman detail koleksi yang hanya
  /// mengetahui id collectible — bukan id quiz-nya.
  static String quizByCollectible(String collectibleId) =>
      '/quiz/collectible/$collectibleId';

  // Pola jalur untuk pendaftaran rute (memakai parameter go_router).
  static const String collectibleDetailPattern = '/collectible/:idOrSlug';
  static const String missionDetailPattern = '/missions/:id';
  static const String quizPattern = '/quiz/:quizId';

  // Tiga segmen, sehingga tidak pernah bentrok dengan `/quiz/:quizId`
  // yang hanya cocok untuk dua segmen.
  static const String quizByCollectiblePattern =
      '/quiz/collectible/:collectibleId';
}
