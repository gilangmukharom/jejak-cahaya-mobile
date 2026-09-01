import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Menggerakkan kamera peta secara halus.
///
/// `MapController` hanya menyediakan perpindahan seketika: memanggilnya pada
/// setiap pembaruan GPS membuat peta tersentak beberapa kali per detik dan
/// pemain kehilangan jejak posisinya sendiri. Kelas ini menyisipkan animasi di
/// antaranya, sehingga peta terasa mengikuti pemain alih-alih melompat
/// menyusulnya — perbedaan yang memisahkan peta navigasi dari peta permainan.
///
/// Dipakai oleh satu layar saja, dan wajib di-[dispose] bersama State-nya.
class GameMapCamera {
  GameMapCamera({required this.controller, required TickerProvider vsync})
      : _animation = AnimationController(vsync: vsync) {
    // Dibuat sekali lalu dipakai ulang. `CurvedAnimation` memasang pendengar
    // pada induknya, jadi membuatnya baru pada tiap gerakan akan menumpuk
    // pendengar yang tidak pernah dilepas selama layar peta terbuka.
    _curved = CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic);
  }

  final MapController controller;
  final AnimationController _animation;
  late final CurvedAnimation _curved;

  /// Peta baru bisa dibaca setelah `onMapReady`. Sebelum itu, [controller.camera]
  /// melempar, jadi permintaan gerak yang datang lebih awal dijalankan langsung
  /// tanpa animasi.
  bool _isReady = false;

  VoidCallback? _tick;

  /// Ditandai dari `MapOptions.onMapReady`.
  void markReady() => _isReady = true;

  /// Menghentikan animasi yang sedang berjalan.
  ///
  /// Dipanggil ketika pemain menyentuh peta: animasi yang terus berjalan sambil
  /// jari menggeser layar membuat peta seolah melawan sentuhan.
  void stop() {
    if (_animation.isAnimating) _animation.stop();
  }

  /// Menggeser, memperbesar, dan memutar kamera dalam satu gerakan.
  ///
  /// [rotationDeg] adalah sudut peta, bukan arah hadap pemain — pemanggil yang
  /// membalik tandanya. Nilai null berarti "pertahankan yang sekarang".
  void animateTo({
    required LatLng center,
    double? zoom,
    double? rotationDeg,
    Duration duration = const Duration(milliseconds: 900),
    Curve curve = Curves.easeOutCubic,
  }) {
    if (!_isReady) {
      controller.moveAndRotate(center, zoom ?? 18, rotationDeg ?? 0);
      return;
    }

    final camera = controller.camera;
    final beginCenter = camera.center;
    final beginZoom = camera.zoom;
    final beginRotation = camera.rotation;

    final endZoom = zoom ?? beginZoom;
    // Diputar lewat selisih terpendek, bukan menuju sudut absolutnya. Tanpa ini,
    // pemain yang berbelok dari 350° ke 10° membuat peta berputar 340° ke arah
    // sebaliknya — satu putaran penuh yang membuat siapa pun kehilangan arah.
    final rotationDelta = rotationDeg == null
        ? 0.0
        : _shortestTurn(from: beginRotation, to: rotationDeg);

    final isAlreadyThere = rotationDelta.abs() < 0.5 &&
        (endZoom - beginZoom).abs() < 0.01 &&
        _metersBetween(beginCenter, center) < 0.5;
    if (isAlreadyThere) return;

    _detachTick();

    _curved.curve = curve;
    void tick() {
      final t = _curved.value;
      controller.moveAndRotate(
        LatLng(
          beginCenter.latitude +
              (center.latitude - beginCenter.latitude) * t,
          beginCenter.longitude +
              (center.longitude - beginCenter.longitude) * t,
        ),
        beginZoom + (endZoom - beginZoom) * t,
        beginRotation + rotationDelta * t,
      );
    }

    _tick = tick;
    _animation
      ..duration = duration
      ..addListener(tick)
      ..forward(from: 0);
  }

  void _detachTick() {
    final previous = _tick;
    if (previous != null) _animation.removeListener(previous);
    _tick = null;
  }

  void dispose() {
    _detachTick();
    _curved.dispose();
    _animation.dispose();
  }

  /// Besar putaran terpendek dari [from] ke [to], dalam derajat, selalu positif.
  ///
  /// Dipakai pemanggil untuk memutuskan apakah sebuah perubahan arah cukup
  /// besar untuk diteruskan ke peta.
  static double turnSize({required double from, required double to}) =>
      _shortestTurn(from: from, to: to).abs();

  /// Selisih sudut terpendek dari [from] ke [to], dalam rentang −180°…180°.
  static double _shortestTurn({required double from, required double to}) {
    final delta = (to - from) % 360;
    if (delta > 180) return delta - 360;
    if (delta < -180) return delta + 360;
    return delta;
  }

  /// Perkiraan kasar jarak dua koordinat dalam meter.
  ///
  /// Sengaja tidak memakai Haversine seperti `LocationService`: nilainya hanya
  /// dipakai untuk menilai apakah sebuah gerakan cukup besar untuk dianimasikan,
  /// dan pada jarak puluhan meter selisih kedua rumus jauh di bawah ambang yang
  /// diperiksa.
  static double _metersBetween(LatLng a, LatLng b) {
    const double metersPerDegree = 111320;
    final dLat = (a.latitude - b.latitude) * metersPerDegree;
    final dLon = (a.longitude - b.longitude) *
        metersPerDegree *
        math.cos(a.latitude * math.pi / 180);
    return math.sqrt(dLat * dLat + dLon * dLon);
  }
}
