/// Jarak dalam bentuk yang enak dibaca: "820 m", "1,4 km", "12 km".
///
/// Dikumpulkan di satu tempat karena jarak muncul di lima layar berbeda —
/// gerbang, peta, radar, kartu di luar jangkauan, dan kompas kiblat — dan
/// masing-masing pernah punya versi sendiri yang memakai titik desimal alih-alih
/// koma, atau menampilkan "0,8 km" alih-alih "800 m".
///
/// Aturannya: di bawah satu kilometer memakai meter bulat, sebab itulah satuan
/// yang bisa dibayangkan orang yang sedang berjalan. Di atasnya memakai
/// kilometer dengan satu desimal, dan desimalnya dilepas begitu angkanya
/// mencapai dua digit — "12,3 km" tidak lebih berguna daripada "12 km" bagi
/// orang yang sedang memutuskan naik kendaraan atau tidak.
String formatDistance(double meters) {
  if (meters.isNaN || meters.isInfinite) return '—';
  if (meters < 1000) return '${meters.round()} m';

  final km = meters / 1000;
  if (km < 10) {
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }
  return '${km.round()} km';
}
