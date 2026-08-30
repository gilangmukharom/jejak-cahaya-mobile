/// Pembantu parsing JSON yang toleran.
///
/// Backend memakai TypeScript bertipe ketat, tetapi JSON tetap bisa mengejutkan:
/// bilangan bulat yang berubah menjadi `double`, kolom nullable yang hilang, atau
/// enum baru yang belum dikenal versi aplikasi lama. Fungsi-fungsi di sini
/// memilih nilai bawaan yang wajar alih-alih melempar exception, agar satu kolom
/// bermasalah tidak menjatuhkan seluruh layar.
class Json {
  const Json._();

  static String str(Object? value, [String fallback = '']) =>
      value is String ? value : fallback;

  static String? strOrNull(Object? value) => value is String ? value : null;

  static int integer(Object? value, [int fallback = 0]) => switch (value) {
        final int v => v,
        final double v => v.round(),
        final String v => int.tryParse(v) ?? fallback,
        _ => fallback,
      };

  static int? intOrNull(Object? value) => switch (value) {
        final int v => v,
        final double v => v.round(),
        final String v => int.tryParse(v),
        _ => null,
      };

  static double decimal(Object? value, [double fallback = 0]) =>
      switch (value) {
        final double v => v,
        final int v => v.toDouble(),
        final String v => double.tryParse(v) ?? fallback,
        _ => fallback,
      };

  static double? doubleOrNull(Object? value) => switch (value) {
        final double v => v,
        final int v => v.toDouble(),
        final String v => double.tryParse(v),
        _ => null,
      };

  static bool boolean(Object? value, {bool fallback = false}) =>
      value is bool ? value : fallback;

  static DateTime dateTime(Object? value) =>
      DateTime.tryParse(Json.str(value))?.toLocal() ?? DateTime.now();

  static DateTime? dateTimeOrNull(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static Map<String, dynamic> map(Object? value) =>
      value is Map<String, dynamic> ? value : const {};

  static Map<String, dynamic>? mapOrNull(Object? value) =>
      value is Map<String, dynamic> ? value : null;

  /// Memetakan array JSON menjadi daftar model, melewati elemen yang bukan objek.
  static List<T> list<T>(
          Object? value, T Function(Map<String, dynamic>) parser) =>
      value is List
          ? value
              .whereType<Map<String, dynamic>>()
              .map(parser)
              .toList(growable: false)
          : const [];

  static List<String> stringList(Object? value) => value is List
      ? value.map((item) => item.toString()).toList(growable: false)
      : const [];

  /// Menghitung peta `{kunci: angka}` — dipakai ringkasan per kategori/rarity.
  static Map<String, int> countMap(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        entry.key.toString(): Json.integer(entry.value),
    };
  }
}
