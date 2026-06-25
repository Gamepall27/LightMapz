import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../routing/models/lat_lng.dart';

abstract interface class NavigationService {
  Future<void> ensureLocationPermission();
  Future<NavigationLocation> getCurrentLocation();
  Stream<NavigationLocation> getLocationStream();
  Stream<double?> getHeadingStream();
}

class DeviceNavigationService implements NavigationService {
  const DeviceNavigationService();

  @override
  Future<void> ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const NavigationPermissionException(
        'Standortdienste sind deaktiviert.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const NavigationPermissionException(
        'Standortberechtigung wurde abgelehnt.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const NavigationPermissionException(
        'Standortberechtigung ist dauerhaft abgelehnt.',
      );
    }
  }

  @override
  Future<NavigationLocation> getCurrentLocation() async {
    await ensureLocationPermission();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
    );
    final position = await Geolocator.getCurrentPosition(
      locationSettings: settings,
    );
    final heading = position.heading.isFinite && position.heading >= 0
        ? position.heading
        : null;

    return NavigationLocation(
      point: LatLng(
        lat: position.latitude,
        lng: position.longitude,
      ),
      headingDegrees: heading,
      speedMetersPerSecond: position.speed.isFinite && position.speed > 0
          ? position.speed
          : null,
    );
  }

  @override
  Stream<NavigationLocation> getLocationStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );

    return Geolocator.getPositionStream(locationSettings: settings).map(
      (position) {
        final heading = position.heading.isFinite && position.heading >= 0
            ? position.heading
            : null;

        return NavigationLocation(
          point: LatLng(
            lat: position.latitude,
            lng: position.longitude,
          ),
          headingDegrees: heading,
          speedMetersPerSecond:
              position.speed.isFinite && position.speed > 0
                  ? position.speed
                  : null,
        );
      },
    );
  }

  @override
  Stream<double?> getHeadingStream() {
    return FlutterCompass.events?.map((event) => event.heading) ??
        const Stream<double?>.empty();
  }
}

class NavigationLocation {
  const NavigationLocation({
    required this.point,
    this.headingDegrees,
    this.speedMetersPerSecond,
  });

  final LatLng point;
  final double? headingDegrees;
  final double? speedMetersPerSecond;
}

class NavigationPermissionException implements Exception {
  const NavigationPermissionException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
