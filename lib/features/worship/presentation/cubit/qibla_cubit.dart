import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/safe_emit.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/qibla_service.dart';
import '../../../../core/storage/app_preferences.dart';

class QiblaState extends Equatable {
  const QiblaState({
    this.latitude,
    this.longitude,
    this.heading,
    this.accuracy = CompassAccuracy.good,
    this.hasCompass = true,
    this.isLocating = false,
  });

  final double? latitude;
  final double? longitude;

  /// Arah hadap perangkat, atau null selama kompas belum memberi bacaan.
  final double? heading;

  final CompassAccuracy accuracy;

  /// False bila perangkat tidak punya magnetometer sama sekali.
  final bool hasCompass;

  final bool isLocating;

  bool get hasLocation => latitude != null && longitude != null;

  /// Sudut kiblat dari posisi saat ini, 0° = utara.
  double? get qiblaBearing => hasLocation
      ? QiblaService.bearingFrom(latitude: latitude!, longitude: longitude!)
      : null;

  double? get distanceToKaabaM => hasLocation
      ? QiblaService.distanceFrom(latitude: latitude!, longitude: longitude!)
      : null;

  /// Berapa derajat pengguna harus berputar agar menghadap kiblat.
  /// Positif berarti memutar ke kanan.
  double? get offsetFromQibla {
    final bearing = qiblaBearing;
    final current = heading;
    if (bearing == null || current == null) return null;

    return QiblaService.offsetToQibla(
      headingDeg: current,
      qiblaBearingDeg: bearing,
    );
  }

  /// Apakah perangkat sudah cukup lurus menghadap kiblat.
  ///
  /// Ambang 3° dipilih dari kenyataan alatnya, bukan dari fikih: magnetometer
  /// ponsel sendiri berderau sekitar 2°, jadi ambang yang lebih ketat hanya
  /// akan membuat penandanya berkedip-kedip tanpa perangkatnya bergerak.
  bool get isAligned {
    final offset = offsetFromQibla;
    return offset != null && offset.abs() <= 3;
  }

  QiblaState copyWith({
    double? latitude,
    double? longitude,
    double? heading,
    CompassAccuracy? accuracy,
    bool? hasCompass,
    bool? isLocating,
  }) =>
      QiblaState(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        heading: heading ?? this.heading,
        accuracy: accuracy ?? this.accuracy,
        hasCompass: hasCompass ?? this.hasCompass,
        isLocating: isLocating ?? this.isLocating,
      );

  @override
  List<Object?> get props =>
      [latitude, longitude, heading, accuracy, hasCompass, isLocating];
}

/// Menyalakan kompas kiblat dan menjaganya tetap mengikuti posisi pengguna.
class QiblaCubit extends Cubit<QiblaState> with SafeEmit<QiblaState> {
  QiblaCubit({
    required LocationService locationService,
    required AppPreferences preferences,
    QiblaService? qiblaService,
  })  : _location = locationService,
        _preferences = preferences,
        _qibla = qiblaService ?? QiblaService(),
        super(const QiblaState());

  final LocationService _location;
  final AppPreferences _preferences;
  final QiblaService _qibla;

  StreamSubscription<CompassReading>? _compass;
  Timer? _compassTimeout;

  Future<void> start() async {
    _resolveLocation();
    _listenToCompass();
  }

  void _resolveLocation() {
    final known = _location.lastKnown;
    if (known != null) {
      emit(
          state.copyWith(latitude: known.latitude, longitude: known.longitude));
      return;
    }

    final saved = _preferences.prayerLocation;
    if (saved != null) {
      emit(
          state.copyWith(latitude: saved.latitude, longitude: saved.longitude));
    }

    unawaited(refreshLocation());
  }

  /// Membaca ulang posisi. Sudut kiblat bergeser terlalu lambat untuk perlu
  /// dipantau terus-menerus — satu kilometer perpindahan mengubahnya kurang
  /// dari 0,01° — jadi ia hanya diperbarui saat layar dibuka atau diminta.
  Future<void> refreshLocation() async {
    emit(state.copyWith(isLocating: true));

    try {
      final position = await _location.getCurrentPosition();
      await _preferences.setPrayerLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      emit(
        state.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
          isLocating: false,
        ),
      );
    } on Object {
      emit(state.copyWith(isLocating: false));
    }
  }

  void _listenToCompass() {
    if (_compass != null) return;

    _compass = _qibla.headingStream.listen(
      (reading) {
        _compassTimeout?.cancel();
        _compassTimeout = null;

        emit(
          state.copyWith(
            heading: reading.headingDeg,
            accuracy: reading.accuracy,
            hasCompass: true,
          ),
        );
      },
      onError: (Object _) => emit(state.copyWith(hasCompass: false)),
    );

    // Perangkat tanpa magnetometer tidak memberi galat — alirannya hanya diam
    // selamanya. Tanpa tenggat ini layar akan menunggu jarum yang tidak akan
    // pernah datang, alih-alih beralih menampilkan sudut kiblatnya sebagai
    // angka yang masih bisa dipakai bersama kompas biasa.
    _compassTimeout = Timer(const Duration(seconds: 3), () {
      if (state.heading == null) emit(state.copyWith(hasCompass: false));
    });
  }

  @override
  Future<void> close() async {
    _compassTimeout?.cancel();
    await _compass?.cancel();
    return super.close();
  }
}
