/// Penanggalan dan jam dalam bahasa Indonesia.
///
/// Ditulis sendiri alih-alih memakai `DateFormat` dari paket intl. Bukan karena
/// paketnya kurang, melainkan karena nama hari dan bulan di sana baru tersedia
/// setelah data lokal selesai dimuat — sesuatu yang terjadi di luar kendali
/// layar yang memanggilnya, dan yang gagalnya muncul sebagai pengecualian saat
/// dijalankan, bukan saat dikompilasi. Untuk dua belas nama bulan dan tujuh
/// nama hari, kepastian itu jauh lebih berharga daripada penghematannya.
const List<String> _dayNames = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

const List<String> _monthNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// "Kamis, 4 September 2026".
String formatLongDate(DateTime date) {
  // `DateTime.weekday` bernilai 1 untuk Senin, sesuai urutan [_dayNames].
  final day = _dayNames[date.weekday - 1];
  final month = _monthNames[date.month - 1];
  return '$day, ${date.day} $month ${date.year}';
}

/// Jam dinding 24 jam: "04:31".
String formatClock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Sisa waktu sebagai hitung mundur: "2 jam 14 menit", "8 menit 30 detik".
///
/// Satuannya berganti mengikuti sisa waktunya. Menampilkan detik ketika masih
/// tersisa tiga jam hanya membuat angkanya berkedip tanpa memberi tahu apa pun;
/// menyembunyikannya ketika tinggal semenit menghilangkan justru bagian yang
/// sedang diperhatikan orang.
String formatCountdown(Duration remaining) {
  final total = remaining.isNegative ? Duration.zero : remaining;

  final hours = total.inHours;
  final minutes = total.inMinutes % 60;
  final seconds = total.inSeconds % 60;

  if (hours > 0) return '$hours jam $minutes menit';
  if (minutes > 0) return '$minutes menit $seconds detik';
  return '$seconds detik';
}
