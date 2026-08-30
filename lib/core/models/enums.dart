// Enum yang mencerminkan nilai di backend.
//
// Setiap enum punya anggota `unknown` dan mem-parsing nilai tak dikenal ke sana
// alih-alih melempar exception. Ini penting untuk aplikasi mobile: kurator bisa
// menambah kategori baru kapan saja, sementara pengguna belum tentu memperbarui
// aplikasinya — kartu bertipe baru sebaiknya tampil apa adanya, bukan membuat
// layar koleksi gagal dimuat.

enum Rarity {
  common('COMMON', 'Common'),
  rare('RARE', 'Rare'),
  epic('EPIC', 'Epic'),
  legendary('LEGENDARY', 'Legendary'),
  unknown('UNKNOWN', 'Lainnya');

  const Rarity(this.value, this.label);

  final String value;
  final String label;

  static Rarity parse(String? raw) => Rarity.values.firstWhere(
        (item) => item.value == raw?.toUpperCase(),
        orElse: () => Rarity.unknown,
      );
}

enum CollectibleType {
  character('CHARACTER', 'Tokoh'),
  artifact('ARTIFACT', 'Artefak'),
  unknown('UNKNOWN', 'Lainnya');

  const CollectibleType(this.value, this.label);

  final String value;
  final String label;

  static CollectibleType parse(String? raw) =>
      CollectibleType.values.firstWhere(
        (item) => item.value == raw?.toUpperCase(),
        orElse: () => CollectibleType.unknown,
      );
}

enum CollectibleCategory {
  companion('COMPANION', 'Sahabat'),
  scholar('SCHOLAR', 'Ulama & Ilmuwan'),
  explorer('EXPLORER', 'Penjelajah'),
  leader('LEADER', 'Pemimpin'),
  nusantara('NUSANTARA', 'Penyebar di Nusantara'),
  artifact('ARTIFACT', 'Artefak Masjid'),
  unknown('UNKNOWN', 'Lainnya');

  const CollectibleCategory(this.value, this.label);

  final String value;
  final String label;

  static CollectibleCategory parse(String? raw) =>
      CollectibleCategory.values.firstWhere(
        (item) => item.value == raw?.toUpperCase(),
        orElse: () => CollectibleCategory.unknown,
      );
}

enum MissionStatus {
  locked('LOCKED', 'Terkunci'),
  inProgress('IN_PROGRESS', 'Sedang berjalan'),
  completed('COMPLETED', 'Selesai'),
  unknown('UNKNOWN', '—');

  const MissionStatus(this.value, this.label);

  final String value;
  final String label;

  bool get isLocked => this == MissionStatus.locked;
  bool get isCompleted => this == MissionStatus.completed;

  static MissionStatus parse(String? raw) => MissionStatus.values.firstWhere(
        (item) => item.value == raw?.toUpperCase(),
        orElse: () => MissionStatus.unknown,
      );
}

enum MissionType {
  sequential('SEQUENTIAL', 'Berurutan'),
  free('FREE', 'Bebas'),
  unknown('UNKNOWN', '—');

  const MissionType(this.value, this.label);

  final String value;
  final String label;

  static MissionType parse(String? raw) => MissionType.values.firstWhere(
        (item) => item.value == raw?.toUpperCase(),
        orElse: () => MissionType.unknown,
      );
}
