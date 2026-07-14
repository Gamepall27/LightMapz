import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../export/gpx_export_service.dart';
import '../../geocoding/geocoding_service.dart';
import '../../navigation/navigation_service.dart';
import '../../routing/models/lat_lng.dart';
import '../../routing/models/route_request.dart';
import '../../routing/models/route_result.dart';
import '../../routing/routing_service.dart';

class RoutePlannerController extends ChangeNotifier {
  RoutePlannerController({
    required RoutingService routingService,
    required GeocodingService geocodingService,
    NavigationService navigationService = const DeviceNavigationService(),
  })  : _routingService = routingService,
        _geocodingService = geocodingService,
        _navigationService = navigationService;

  final RoutingService _routingService;
  final GeocodingService _geocodingService;
  final NavigationService _navigationService;

  LatLng start = const LatLng(lat: 51.2277, lng: 6.7735);
  LatLng destination = const LatLng(lat: 51.4508, lng: 7.0131);
  String startAddress = 'Kohlmeisenweg 18, 58507 Lüdenscheid';
  String destinationAddress = 'Homertturm, 58518 Lüdenscheid';
  List<RouteWaypoint> waypoints = const [];
  int roadAvoidanceStrictness = 50;
  int greenwayDetourRadiusKm = 10;
  int minimumFieldWaySharePercent = 60;
  double averageSpeedKmh = 18;

  RouteResult? route;
  bool isLoading = false;
  bool isNavigationStarting = false;
  bool isNavigationActive = false;
  String? errorMessage;
  String? navigationErrorMessage;
  LatLng? currentLocation;
  double? currentHeadingDegrees;
  NavigationStats? navigationStats;
  bool _isDisposed = false;
  LatLng? _startMapPoint;
  LatLng? _destinationMapPoint;
  int _nextWaypointId = 1;
  StreamSubscription<NavigationLocation>? _locationSubscription;
  StreamSubscription<double?>? _headingSubscription;
  Timer? _navigationStatsTimer;
  NavigationLocation? _lastNavigationLocation;

  NavigationStats? get displayedNavigationStats {
    final currentStats = navigationStats;

    if (currentStats != null) {
      return currentStats;
    }

    final currentRoute = route;

    if (currentRoute == null) {
      return null;
    }

    final speedMetersPerSecond = averageSpeedKmh * 1000 / 3600;
    final durationSeconds = speedMetersPerSecond <= 0
        ? 0
        : (currentRoute.distanceMeters / speedMetersPerSecond).round();

    return NavigationStats(
      remainingDistanceMeters: currentRoute.distanceMeters,
      remainingDurationSeconds: durationSeconds,
      estimatedArrivalTime: DateTime.now().add(
        Duration(seconds: durationSeconds),
      ),
    );
  }

  void updateStartAddress(String value) {
    startAddress = value;
    _startMapPoint = null;
    _clearRouteState();
    _stopNavigationSubscriptions();
    notifyListeners();
  }

  void updateDestinationAddress(String value) {
    destinationAddress = value;
    _destinationMapPoint = null;
    _clearRouteState();
    _stopNavigationSubscriptions();
    notifyListeners();
  }

  void setStartFromMap(LatLng point) {
    start = point;
    startAddress = _formatMapPointLabel(point);
    _startMapPoint = point;
    _clearRouteState();
    _stopNavigationSubscriptions();
    notifyListeners();
  }

  void setDestinationFromMap(LatLng point) {
    destination = point;
    destinationAddress = _formatMapPointLabel(point);
    _destinationMapPoint = point;
    _clearRouteState();
    _stopNavigationSubscriptions();
    notifyListeners();
  }

  Future<bool> setStartToCurrentLocation() async {
    return _setEndpointToCurrentLocation(isStart: true);
  }

  Future<bool> setDestinationToCurrentLocation() async {
    return _setEndpointToCurrentLocation(isStart: false);
  }

  void addWaypoint() {
    waypoints = [
      ...waypoints,
      RouteWaypoint(id: _createWaypointId(), address: ''),
    ];
    _clearRouteState();
    _stopNavigationSubscriptions();
    notifyListeners();
  }

  void addWaypointFromMap(LatLng point) {
    waypoints = [
      ...waypoints,
      RouteWaypoint(
        id: _createWaypointId(),
        address: _formatMapPointLabel(point),
        point: point,
      ),
    ];
    _clearRouteState();
    _stopNavigationSubscriptions();
    notifyListeners();
  }

  void updateWaypointAddress(String waypointId, String value) {
    waypoints = waypoints.map((waypoint) {
      if (waypoint.id != waypointId) {
        return waypoint;
      }

      return waypoint.copyWith(
        address: value,
        clearPoint: true,
      );
    }).toList();
    _clearRouteState();
    _stopNavigationSubscriptions();
    notifyListeners();
  }

  void moveWaypointUp(String waypointId) {
    _moveWaypoint(waypointId, -1);
  }

  void moveWaypointDown(String waypointId) {
    _moveWaypoint(waypointId, 1);
  }

  void removeWaypoint(String waypointId) {
    waypoints = waypoints
        .where((waypoint) => waypoint.id != waypointId)
        .toList(growable: false);
    _clearRouteState();
    _stopNavigationSubscriptions();
    notifyListeners();
  }

  void updateRoadAvoidanceStrictness(int value) {
    roadAvoidanceStrictness = value.clamp(0, 100).toInt();
    _clearRouteState();
    _stopNavigationSubscriptions();
    notifyListeners();
  }

  void updateGreenwayDetourRadiusKm(int value) {
    greenwayDetourRadiusKm = value.clamp(5, 12).toInt();
    _clearRouteState();
    _stopNavigationSubscriptions();
    notifyListeners();
  }

  void updateMinimumFieldWaySharePercent(int value) {
    minimumFieldWaySharePercent = value.clamp(0, 100).toInt();
    _clearRouteState();
    _stopNavigationSubscriptions();
    notifyListeners();
  }

  void updateAverageSpeedKmh(double value) {
    averageSpeedKmh = value.clamp(5, 45).toDouble();
    errorMessage = null;
    notifyListeners();
  }

  Future<void> startNavigation() async {
    if (route == null || route!.geometry.length < 2) {
      navigationErrorMessage = 'Bitte zuerst eine Route berechnen.';
      notifyListeners();
      return;
    }

    isNavigationStarting = true;
    navigationErrorMessage = null;
    notifyListeners();

    try {
      await _navigationService.ensureLocationPermission();
      await _locationSubscription?.cancel();
      await _headingSubscription?.cancel();

      isNavigationActive = true;
      final currentLocation = await _navigationService.getCurrentLocation();
      _handleLocationUpdate(currentLocation);
      _locationSubscription = _navigationService.getLocationStream().listen(
            _handleLocationUpdate,
            onError: _handleNavigationError,
          );
      _headingSubscription = _navigationService.getHeadingStream().listen(
            _handleHeadingUpdate,
            onError: (_) {},
          );
      _navigationStatsTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _recalculateNavigationStats(),
      );
    } on Exception catch (error) {
      navigationErrorMessage = 'Navigation konnte nicht gestartet werden: '
          '$error';
      isNavigationActive = false;
    } finally {
      isNavigationStarting = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<void> stopNavigation() async {
    _stopNavigationSubscriptions();
    notifyListeners();
  }

  Future<void> calculateRoute() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final resolvedStart = await _resolveAddress(startAddress, 'Startadresse');
      final resolvedWaypoints = <LatLng>[];

      for (var index = 0; index < waypoints.length; index++) {
        final waypoint = waypoints[index];
        resolvedWaypoints.add(
          await _resolveLocation(
            waypoint.address,
            'Zwischenstopp ${index + 1}',
            waypoint.point,
          ),
        );
      }

      final resolvedDestination = await _resolveAddress(
        destinationAddress,
        'Zieladresse',
      );

      start = resolvedStart;
      destination = resolvedDestination;
      waypoints = [
        for (var index = 0; index < waypoints.length; index++)
          waypoints[index].copyWith(point: resolvedWaypoints[index]),
      ];
      route = await _routingService.calculateRoute(
        RouteRequest(
          start: resolvedStart,
          destination: resolvedDestination,
          waypoints: resolvedWaypoints,
          roadAvoidanceStrictness: roadAvoidanceStrictness,
          greenwayDetourRadiusKm:
              roadAvoidanceStrictness == 100 ? greenwayDetourRadiusKm : null,
          minimumFieldWaySharePercent: roadAvoidanceStrictness == 100
              ? minimumFieldWaySharePercent
              : null,
        ),
      );
    } on Exception catch (error) {
      errorMessage = 'Die Route konnte nicht berechnet werden: $error';
    } finally {
      isLoading = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  void importGpxRoute(GpxRouteDocument document) {
    if (document.geometry.length < 2) {
      throw Exception('Die GPX-Datei enthaelt keine gueltige Route.');
    }

    final importedWaypoints = document.waypoints.length >= 2
        ? document.waypoints
        : [
            GpxWaypoint(name: 'Start', point: document.geometry.first),
            GpxWaypoint(name: 'Ziel', point: document.geometry.last),
          ];
    final importedStart = importedWaypoints.first;
    final importedDestination = importedWaypoints.last;

    _stopNavigationSubscriptions();

    start = importedStart.point;
    destination = importedDestination.point;
    startAddress =
        _normalizeImportedLabel(importedStart.name, importedStart.point);
    destinationAddress = _normalizeImportedLabel(
      importedDestination.name,
      importedDestination.point,
    );
    _startMapPoint = importedStart.point;
    _destinationMapPoint = importedDestination.point;
    waypoints = [
      for (final waypoint
          in importedWaypoints.skip(1).take(importedWaypoints.length - 2))
        RouteWaypoint(
          id: _createWaypointId(),
          address: _normalizeImportedLabel(waypoint.name, waypoint.point),
          point: waypoint.point,
        ),
    ];

    final importedDistanceMeters = _calculateGeometryDistanceMeters(
      document.geometry,
    );
    route = RouteResult(
      geometry: document.geometry,
      distanceMeters: importedDistanceMeters,
      durationSeconds: _calculateDurationSecondsFromAverageSpeed(
        importedDistanceMeters,
      ),
      roadSharePercent: 0,
      cyclewaySharePercent: 0,
      pathSharePercent: 0,
      warnings: const [
        'Aus GPX importiert. Streckenanteile sind nicht verfuegbar.',
      ],
      segments: const [],
    );
    errorMessage = null;
    navigationErrorMessage = null;
    navigationStats = null;
    currentLocation = null;
    currentHeadingDegrees = null;
    notifyListeners();
  }

  Future<LatLng> _resolveAddress(String address, String fieldName) async {
    LatLng? mapPoint;

    if (fieldName == 'Startadresse') {
      mapPoint = _startMapPoint;
    } else if (fieldName == 'Zieladresse') {
      mapPoint = _destinationMapPoint;
    }

    return _resolveLocation(address, fieldName, mapPoint);
  }

  Future<LatLng> _resolveLocation(
    String address,
    String fieldName,
    LatLng? mapPoint,
  ) async {
    if (mapPoint != null) {
      return mapPoint;
    }

    final trimmed = address.trim();

    if (trimmed.length < 3) {
      throw Exception('$fieldName ist zu kurz.');
    }

    final results = await _geocodingService.search(trimmed);

    if (results.isEmpty) {
      throw Exception('$fieldName wurde nicht gefunden.');
    }

    return results.first.point;
  }

  String _createWaypointId() {
    return 'waypoint_${_nextWaypointId++}';
  }

  void _moveWaypoint(String waypointId, int offset) {
    final currentIndex = waypoints.indexWhere(
      (waypoint) => waypoint.id == waypointId,
    );
    final targetIndex = currentIndex + offset;

    if (currentIndex < 0 ||
        targetIndex < 0 ||
        targetIndex >= waypoints.length) {
      return;
    }

    final updatedWaypoints = [...waypoints];
    final waypoint = updatedWaypoints.removeAt(currentIndex);
    updatedWaypoints.insert(targetIndex, waypoint);
    waypoints = updatedWaypoints;
    _clearRouteState();
    _stopNavigationSubscriptions();
    notifyListeners();
  }

  void _clearRouteState() {
    route = null;
    errorMessage = null;
    navigationStats = null;
    navigationErrorMessage = null;
  }

  String _normalizeImportedLabel(String label, LatLng point) {
    final trimmed = label.trim();

    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    return _formatMapPointLabel(point);
  }

  String _formatMapPointLabel(LatLng point) {
    return 'Kartenpunkt ${point.lat.toStringAsFixed(5)}, '
        '${point.lng.toStringAsFixed(5)}';
  }

  Future<bool> _setEndpointToCurrentLocation({required bool isStart}) async {
    navigationErrorMessage = null;
    notifyListeners();

    try {
      final location = await _navigationService.getCurrentLocation();

      _stopNavigationSubscriptions();

      if (isStart) {
        start = location.point;
        startAddress = 'Eigener Standort';
        _startMapPoint = location.point;
      } else {
        destination = location.point;
        destinationAddress = 'Eigener Standort';
        _destinationMapPoint = location.point;
      }

      currentLocation = location.point;
      currentHeadingDegrees = location.headingDegrees ?? currentHeadingDegrees;
      _clearRouteState();
      return true;
    } on Exception catch (error) {
      navigationErrorMessage = 'Standort konnte nicht ermittelt werden: '
          '$error';
      return false;
    } finally {
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  void _handleLocationUpdate(NavigationLocation location) {
    _lastNavigationLocation = location;
    currentLocation = location.point;
    currentHeadingDegrees = location.headingDegrees ?? currentHeadingDegrees;
    navigationStats = _calculateNavigationStats(location);

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _handleHeadingUpdate(double? headingDegrees) {
    if (headingDegrees == null || !headingDegrees.isFinite) {
      return;
    }

    currentHeadingDegrees = headingDegrees;

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _handleNavigationError(Object error) {
    navigationErrorMessage = 'Standort konnte nicht aktualisiert werden: '
        '$error';
    isNavigationActive = false;
    _stopNavigationSubscriptions();

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _stopNavigationSubscriptions() {
    _locationSubscription?.cancel();
    _headingSubscription?.cancel();
    _navigationStatsTimer?.cancel();
    _locationSubscription = null;
    _headingSubscription = null;
    _navigationStatsTimer = null;
    _lastNavigationLocation = null;
    isNavigationStarting = false;
    isNavigationActive = false;
    currentHeadingDegrees = null;
    currentLocation = null;
    navigationStats = null;
  }

  NavigationStats? _calculateNavigationStats(NavigationLocation location) {
    final geometry = route?.geometry ?? const [];

    if (geometry.length < 2) {
      return null;
    }

    final remainingMeters = _remainingDistanceMeters(
      location.point,
      geometry,
    );
    final speedMetersPerSecond =
        location.speedMetersPerSecond ?? averageSpeedKmh * 1000 / 3600;
    final durationSeconds = speedMetersPerSecond <= 0
        ? 0
        : (remainingMeters / speedMetersPerSecond).round();

    return NavigationStats(
      remainingDistanceMeters: remainingMeters,
      remainingDurationSeconds: durationSeconds,
      estimatedArrivalTime: DateTime.now().add(
        Duration(seconds: durationSeconds),
      ),
      nextInstruction: _nextNavigationInstruction(
        location.point,
        geometry,
      ),
    );
  }

  void _recalculateNavigationStats() {
    final location = _lastNavigationLocation;

    if (!isNavigationActive || location == null) {
      return;
    }

    navigationStats = _calculateNavigationStats(location);

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  NavigationInstruction? _nextNavigationInstruction(
    LatLng location,
    List<LatLng> geometry,
  ) {
    if (geometry.length < 3) {
      return null;
    }

    final progress = _routeProgress(location, geometry);
    var distanceToPoint = progress.distanceToNextPointMeters;

    for (var index = progress.nextPointIndex;
        index < geometry.length - 1;
        index++) {
      if (index > progress.nextPointIndex) {
        distanceToPoint += _distanceMeters(
          geometry[index - 1],
          geometry[index],
        );
      }

      if (distanceToPoint < 25) {
        continue;
      }

      final delta = _turnDeltaDegrees(
        _bearingDegrees(geometry[index - 1], geometry[index]),
        _bearingDegrees(geometry[index], geometry[index + 1]),
      );

      if (delta.abs() < 35) {
        continue;
      }

      return NavigationInstruction(
        distanceMeters: distanceToPoint,
        text: delta > 0 ? 'Rechts abbiegen' : 'Links abbiegen',
      );
    }

    return NavigationInstruction(
      distanceMeters: _remainingDistanceMeters(location, geometry),
      text: 'Dem Routenverlauf folgen',
    );
  }

  double _remainingDistanceMeters(LatLng location, List<LatLng> geometry) {
    final progress = _routeProgress(location, geometry);
    var remaining = progress.distanceToNextPointMeters;

    for (var index = progress.nextPointIndex;
        index < geometry.length - 1;
        index++) {
      remaining += _distanceMeters(geometry[index], geometry[index + 1]);
    }

    return remaining;
  }

  double _calculateGeometryDistanceMeters(List<LatLng> geometry) {
    var distanceMeters = 0.0;

    for (var index = 0; index < geometry.length - 1; index++) {
      distanceMeters += _distanceMeters(geometry[index], geometry[index + 1]);
    }

    return distanceMeters;
  }

  int _calculateDurationSecondsFromAverageSpeed(double distanceMeters) {
    final speedMetersPerSecond = averageSpeedKmh * 1000 / 3600;

    if (speedMetersPerSecond <= 0) {
      return 0;
    }

    return (distanceMeters / speedMetersPerSecond).round();
  }

  _RouteProgress _routeProgress(LatLng location, List<LatLng> geometry) {
    var nearestSegmentIndex = 0;
    var nearestProjection = geometry.first;
    var nearestDistanceMeters = double.infinity;

    for (var index = 0; index < geometry.length - 1; index++) {
      final projection = _projectPointToSegment(
        location,
        geometry[index],
        geometry[index + 1],
      );
      final distance = _distanceMeters(location, projection);

      if (distance < nearestDistanceMeters) {
        nearestDistanceMeters = distance;
        nearestProjection = projection;
        nearestSegmentIndex = index;
      }
    }

    var remaining = _distanceMeters(
      nearestProjection,
      geometry[nearestSegmentIndex + 1],
    );

    return _RouteProgress(
      nextPointIndex: nearestSegmentIndex + 1,
      distanceToNextPointMeters: remaining,
    );
  }

  LatLng _projectPointToSegment(LatLng point, LatLng start, LatLng end) {
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng =
        metersPerDegreeLat * math.cos(_toRadians((start.lat + end.lat) / 2));
    final startX = start.lng * metersPerDegreeLng;
    final startY = start.lat * metersPerDegreeLat;
    final endX = end.lng * metersPerDegreeLng;
    final endY = end.lat * metersPerDegreeLat;
    final pointX = point.lng * metersPerDegreeLng;
    final pointY = point.lat * metersPerDegreeLat;
    final dx = endX - startX;
    final dy = endY - startY;
    final lengthSquared = dx * dx + dy * dy;

    if (lengthSquared == 0) {
      return start;
    }

    final t =
        (((pointX - startX) * dx + (pointY - startY) * dy) / lengthSquared)
            .clamp(0.0, 1.0);

    return LatLng(
      lat: (startY + dy * t) / metersPerDegreeLat,
      lng: (startX + dx * t) / metersPerDegreeLng,
    );
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _toRadians(b.lat - a.lat);
    final dLng = _toRadians(b.lng - a.lng);
    final lat1 = _toRadians(a.lat);
    final lat2 = _toRadians(b.lat);

    final haversine = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  double _toDegrees(double radians) {
    return radians * 180 / math.pi;
  }

  double _bearingDegrees(LatLng from, LatLng to) {
    final fromLat = _toRadians(from.lat);
    final toLat = _toRadians(to.lat);
    final deltaLng = _toRadians(to.lng - from.lng);
    final y = math.sin(deltaLng) * math.cos(toLat);
    final x = math.cos(fromLat) * math.sin(toLat) -
        math.sin(fromLat) * math.cos(toLat) * math.cos(deltaLng);

    return (_toDegrees(math.atan2(y, x)) + 360) % 360;
  }

  double _turnDeltaDegrees(double fromBearing, double toBearing) {
    var delta = (toBearing - fromBearing + 540) % 360 - 180;

    if (delta == -180) {
      delta = 180;
    }

    return delta;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopNavigationSubscriptions();
    super.dispose();
  }
}

class NavigationStats {
  const NavigationStats({
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
    required this.estimatedArrivalTime,
    this.nextInstruction,
  });

  final double remainingDistanceMeters;
  final int remainingDurationSeconds;
  final DateTime estimatedArrivalTime;
  final NavigationInstruction? nextInstruction;
}

class NavigationInstruction {
  const NavigationInstruction({
    required this.text,
    required this.distanceMeters,
  });

  final String text;
  final double distanceMeters;
}

class _RouteProgress {
  const _RouteProgress({
    required this.nextPointIndex,
    required this.distanceToNextPointMeters,
  });

  final int nextPointIndex;
  final double distanceToNextPointMeters;
}

class RouteWaypoint {
  const RouteWaypoint({
    required this.id,
    required this.address,
    this.point,
  });

  final String id;
  final String address;
  final LatLng? point;

  RouteWaypoint copyWith({
    String? address,
    LatLng? point,
    bool clearPoint = false,
  }) {
    return RouteWaypoint(
      id: id,
      address: address ?? this.address,
      point: clearPoint ? null : point ?? this.point,
    );
  }
}
