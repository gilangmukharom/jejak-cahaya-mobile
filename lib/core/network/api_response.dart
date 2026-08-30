/// Bentuk amplop response yang dipakai seluruh endpoint backend:
/// `{ success, message, data, meta? }`.
class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    required this.message,
    required this.data,
    this.meta,
  });

  final bool success;
  final String message;
  final T data;
  final PaginationMeta? meta;

  /// Membongkar amplop dan memetakan `data` lewat [fromData].
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? data) fromData,
  ) {
    final meta = json['meta'];

    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: fromData(json['data']),
      meta: meta is Map<String, dynamic> ? PaginationMeta.fromJson(meta) : null,
    );
  }
}

class PaginationMeta {
  const PaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) => PaginationMeta(
        page: json['page'] as int? ?? 1,
        limit: json['limit'] as int? ?? 20,
        total: json['total'] as int? ?? 0,
        totalPages: json['totalPages'] as int? ?? 0,
        hasNext: json['hasNext'] as bool? ?? false,
        hasPrev: json['hasPrev'] as bool? ?? false,
      );
}

/// Halaman hasil beserta metadata paginasinya.
class Paginated<T> {
  const Paginated({required this.items, required this.meta});

  final List<T> items;
  final PaginationMeta? meta;

  bool get hasMore => meta?.hasNext ?? false;
  int get nextPage => (meta?.page ?? 1) + 1;
}
