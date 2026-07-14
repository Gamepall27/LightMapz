import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/export/gpx_export_service.dart';
import 'package:lightmapz/features/route_planner/route_planner_controller.dart';
import 'package:lightmapz/geocoding/geocoding_service.dart';
import 'package:lightmapz/geocoding/models/geocode_result.dart';
import 'package:lightmapz/navigation/navigation_service.dart';
import 'package:lightmapz/routing/models/lat_lng.dart';
import 'package:lightmapz/routing/models/route_request.dart';
import 'package:lightmapz/routing/models/route_result.dart';
import 'package:lightmapz/routing/routing_service.dart';

void main() {
  group('RoutePlannerController', () {
    test('starts with MVP default coordinates and strictness', () {
      final controller = RoutePlannerController(
        routingService: _SuccessfulRoutingService(),
        geocodingService: _FakeGeocodingService(),
      );
      addTearDown(controller.dispose);

      expect(controller.start, const LatLng(lat: 51.2277, lng: 6.7735));
      expect(controller.destination, const LatLng(lat: 51.4508, lng: 7.0131));
      expect(controller.roadAvoidanceStrictness, 50);
      expect(controller.greenwayDetourRadiusKm, 10);
      expect(controller.minimumFieldWaySharePercent, 60);
      expect(controller.averageSpeedKmh, 18);
      expect(controller.waypoints, isEmpty);
      expect(controller.route, isNull);
      expect(controller.isLoading, isFalse);
    });

    test('clears stale route when inputs change', () async {
      final controller = RoutePlannerController(
        routingService: _SuccessfulRoutingService(),
        geocodingService: _FakeGeocodingService(),
      );
      addTearDown(controller.dispose);

      await controller.calculateRoute();
      expect(controller.route, isNotNull);

      controller.updateStartAddress('Neuer Start');

      expect(controller.route, isNull);
      expect(controller.errorMessage, isNull);
    });

    test('adds, updates and removes waypoints', () {
      final controller = RoutePlannerController(
        routingService: _SuccessfulRoutingService(),
        geocodingService: _FakeGeocodingService(),
      );
      addTearDown(controller.dispose);

      controller.addWaypoint();
      final waypointId = controller.waypoints.single.id;

      controller.updateWaypointAddress(waypointId, 'Zwischenstopp Test');

      expect(controller.waypoints.single.address, 'Zwischenstopp Test');
      expect(controller.waypoints.single.point, isNull);

      controller.removeWaypoint(waypointId);

      expect(controller.waypoints, isEmpty);
    });

    test('moves waypoints up and down', () {
      final controller = RoutePlannerController(
        routingService: _SuccessfulRoutingService(),
        geocodingService: _FakeGeocodingService(),
      );
      addTearDown(controller.dispose);

      controller.addWaypoint();
      controller.updateWaypointAddress(
        controller.waypoints[0].id,
        'Zwischenstopp 1',
      );
      controller.addWaypoint();
      controller.updateWaypointAddress(
        controller.waypoints[1].id,
        'Zwischenstopp 2',
      );

      final secondWaypointId = controller.waypoints[1].id;

      controller.moveWaypointUp(secondWaypointId);

      expect(controller.waypoints[0].address, 'Zwischenstopp 2');
      expect(controller.waypoints[1].address, 'Zwischenstopp 1');

      controller.moveWaypointDown(secondWaypointId);

      expect(controller.waypoints[0].address, 'Zwischenstopp 1');
      expect(controller.waypoints[1].address, 'Zwischenstopp 2');
    });

    test('clamps road avoidance strictness to 0 through 100', () {
      final controller = RoutePlannerController(
        routingService: _SuccessfulRoutingService(),
        geocodingService: _FakeGeocodingService(),
      );
      addTearDown(controller.dispose);

      controller.updateRoadAvoidanceStrictness(150);
      expect(controller.roadAvoidanceStrictness, 100);

      controller.updateRoadAvoidanceStrictness(-20);
      expect(controller.roadAvoidanceStrictness, 0);
    });

    test('clamps greenway search radius to 5 through 12', () {
      final controller = RoutePlannerController(
        routingService: _SuccessfulRoutingService(),
        geocodingService: _FakeGeocodingService(),
      );
      addTearDown(controller.dispose);

      controller.updateGreenwayDetourRadiusKm(200);
      expect(controller.greenwayDetourRadiusKm, 12);

      controller.updateGreenwayDetourRadiusKm(1);
      expect(controller.greenwayDetourRadiusKm, 5);
    });

    test('clamps minimum field-way share to 0 through 100', () {
      final controller = RoutePlannerController(
        routingService: _SuccessfulRoutingService(),
        geocodingService: _FakeGeocodingService(),
      );
      addTearDown(controller.dispose);

      controller.updateMinimumFieldWaySharePercent(150);
      expect(controller.minimumFieldWaySharePercent, 100);

      controller.updateMinimumFieldWaySharePercent(-20);
      expect(controller.minimumFieldWaySharePercent, 0);
    });

    test('clamps average speed to a realistic cycling range', () {
      final controller = RoutePlannerController(
        routingService: _SuccessfulRoutingService(),
        geocodingService: _FakeGeocodingService(),
      );
      addTearDown(controller.dispose);

      controller.updateAverageSpeedKmh(60);
      expect(controller.averageSpeedKmh, 45);

      controller.updateAverageSpeedKmh(2);
      expect(controller.averageSpeedKmh, 5);
    });

    test('passes current request to RoutingService and stores result',
        () async {
      final service = _SuccessfulRoutingService();
      final controller = RoutePlannerController(
        routingService: service,
        geocodingService: _FakeGeocodingService(),
      );
      addTearDown(controller.dispose);

      controller.updateStartAddress('Start Test');
      controller.updateDestinationAddress('Ziel Test');
      controller.addWaypoint();
      controller.updateWaypointAddress(
        controller.waypoints.single.id,
        'Zwischenstopp Test',
      );
      controller.updateRoadAvoidanceStrictness(100);
      controller.updateGreenwayDetourRadiusKm(12);
      controller.updateMinimumFieldWaySharePercent(80);

      await controller.calculateRoute();

      expect(service.lastRequest?.start, const LatLng(lat: 50.1, lng: 7.1));
      expect(
        service.lastRequest?.destination,
        const LatLng(lat: 50.2, lng: 7.2),
      );
      expect(service.lastRequest?.waypoints, [
        const LatLng(lat: 50.15, lng: 7.15),
      ]);
      expect(service.lastRequest?.roadAvoidanceStrictness, 100);
      expect(service.lastRequest?.greenwayDetourRadiusKm, 12);
      expect(service.lastRequest?.minimumFieldWaySharePercent, 80);
      expect(controller.route, service.result);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
    });

    test('stores a readable error when RoutingService fails', () async {
      final controller = RoutePlannerController(
        routingService: _FailingRoutingService(),
        geocodingService: _FakeGeocodingService(),
      );
      addTearDown(controller.dispose);

      await controller.calculateRoute();

      expect(controller.route, isNull);
      expect(controller.isLoading, isFalse);
      expect(
        controller.errorMessage,
        contains('Die Route konnte nicht berechnet werden'),
      );
    });

    test('uses map points without geocoding them', () async {
      final service = _SuccessfulRoutingService();
      final controller = RoutePlannerController(
        routingService: service,
        geocodingService: _ThrowingGeocodingService(),
      );
      addTearDown(controller.dispose);

      controller.setStartFromMap(const LatLng(lat: 51, lng: 7));
      controller.addWaypointFromMap(const LatLng(lat: 51.1, lng: 7.1));
      controller.setDestinationFromMap(const LatLng(lat: 51.2, lng: 7.2));

      await controller.calculateRoute();

      expect(service.lastRequest?.start, const LatLng(lat: 51, lng: 7));
      expect(service.lastRequest?.waypoints, [
        const LatLng(lat: 51.1, lng: 7.1),
      ]);
      expect(
        service.lastRequest?.destination,
        const LatLng(lat: 51.2, lng: 7.2),
      );
    });

    test('starts navigation and updates live route stats', () async {
      final navigationService = _FakeNavigationService();
      navigationService.currentLocation = const NavigationLocation(
        point: LatLng(lat: 51.2277, lng: 6.7735),
        headingDegrees: 12,
        speedMetersPerSecond: 5,
      );
      final controller = RoutePlannerController(
        routingService: _SuccessfulRoutingService(),
        geocodingService: _FakeGeocodingService(),
        navigationService: navigationService,
      );
      addTearDown(controller.dispose);
      addTearDown(navigationService.dispose);

      await controller.calculateRoute();
      await controller.startNavigation();

      navigationService.addLocation(
        const NavigationLocation(
          point: LatLng(lat: 51.2277, lng: 6.7735),
          headingDegrees: 42,
          speedMetersPerSecond: 5,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.isNavigationActive, isTrue);
      expect(
        controller.currentLocation,
        const LatLng(lat: 51.2277, lng: 6.7735),
      );
      expect(controller.currentHeadingDegrees, 42);
      expect(controller.navigationStats, isNotNull);
      expect(
        controller.navigationStats!.remainingDistanceMeters,
        greaterThan(0),
      );
    });

    test('uses current location as start or destination', () async {
      final navigationService = _FakeNavigationService()
        ..currentLocation = const NavigationLocation(
          point: LatLng(lat: 51.5, lng: 7.5),
          headingDegrees: 20,
        );
      final controller = RoutePlannerController(
        routingService: _SuccessfulRoutingService(),
        geocodingService: _FakeGeocodingService(),
        navigationService: navigationService,
      );
      addTearDown(controller.dispose);
      addTearDown(navigationService.dispose);

      await controller.setStartToCurrentLocation();

      expect(controller.startAddress, 'Eigener Standort');
      expect(controller.start, const LatLng(lat: 51.5, lng: 7.5));

      navigationService.currentLocation = const NavigationLocation(
        point: LatLng(lat: 51.6, lng: 7.6),
      );
      await controller.setDestinationToCurrentLocation();

      expect(controller.destinationAddress, 'Eigener Standort');
      expect(controller.destination, const LatLng(lat: 51.6, lng: 7.6));
    });

    test('remaining distance follows progress along the route', () async {
      final navigationService = _FakeNavigationService()
        ..currentLocation = const NavigationLocation(
          point: LatLng(lat: 0, lng: 0.02),
          speedMetersPerSecond: 10,
        );
      final controller = RoutePlannerController(
        routingService: _SuccessfulRoutingService(),
        geocodingService: _FakeGeocodingService(),
        navigationService: navigationService,
      );
      addTearDown(controller.dispose);
      addTearDown(navigationService.dispose);
      controller.route = const RouteResult(
        geometry: [
          LatLng(lat: 0, lng: 0),
          LatLng(lat: 0, lng: 0.01),
          LatLng(lat: 0, lng: 0.03),
        ],
        distanceMeters: 3330,
        durationSeconds: 333,
        roadSharePercent: 0,
        cyclewaySharePercent: 100,
        pathSharePercent: 0,
        warnings: [],
        segments: [],
      );

      await controller.startNavigation();

      expect(
        controller.navigationStats!.remainingDistanceMeters,
        lessThan(1700),
      );
      expect(
        controller.navigationStats!.remainingDistanceMeters,
        greaterThan(900),
      );
    });

    test('imports GPX routes into start, destination, waypoints, and geometry',
        () {
      final controller = RoutePlannerController(
        routingService: _SuccessfulRoutingService(),
        geocodingService: _FakeGeocodingService(),
      );
      addTearDown(controller.dispose);

      controller.importGpxRoute(
        const GpxRouteDocument(
          name: 'Import',
          waypoints: [
            GpxWaypoint(
              name: 'Start GPX',
              point: LatLng(lat: 51.1, lng: 7.1),
            ),
            GpxWaypoint(
              name: 'Zwischenstopp GPX',
              point: LatLng(lat: 51.2, lng: 7.2),
            ),
            GpxWaypoint(
              name: 'Ziel GPX',
              point: LatLng(lat: 51.3, lng: 7.3),
            ),
          ],
          geometry: [
            LatLng(lat: 51.1, lng: 7.1),
            LatLng(lat: 51.15, lng: 7.15),
            LatLng(lat: 51.2, lng: 7.2),
            LatLng(lat: 51.3, lng: 7.3),
          ],
        ),
      );

      expect(controller.startAddress, 'Start GPX');
      expect(controller.destinationAddress, 'Ziel GPX');
      expect(controller.start, const LatLng(lat: 51.1, lng: 7.1));
      expect(controller.destination, const LatLng(lat: 51.3, lng: 7.3));
      expect(controller.waypoints, hasLength(1));
      expect(controller.waypoints.single.address, 'Zwischenstopp GPX');
      expect(
          controller.waypoints.single.point, const LatLng(lat: 51.2, lng: 7.2));
      expect(controller.route, isNotNull);
      expect(controller.route!.geometry, hasLength(4));
      expect(
        controller.route!.warnings,
        contains('Aus GPX importiert. Streckenanteile sind nicht verfuegbar.'),
      );
    });
  });
}

class _FakeGeocodingService implements GeocodingService {
  @override
  Future<List<GeocodeResult>> search(String query) async {
    if (query.contains('Zwischenstopp')) {
      return const [
        GeocodeResult(
          label: 'Zwischenstopp Test',
          point: LatLng(lat: 50.15, lng: 7.15),
        ),
      ];
    }

    if (query.contains('Ziel')) {
      return const [
        GeocodeResult(
          label: 'Ziel Test',
          point: LatLng(lat: 50.2, lng: 7.2),
        ),
      ];
    }

    return const [
      GeocodeResult(
        label: 'Start Test',
        point: LatLng(lat: 50.1, lng: 7.1),
      ),
    ];
  }
}

class _ThrowingGeocodingService implements GeocodingService {
  @override
  Future<List<GeocodeResult>> search(String query) async {
    throw Exception('geocoding should not be called');
  }
}

class _SuccessfulRoutingService implements RoutingService {
  final result = const RouteResult(
    geometry: [
      LatLng(lat: 51.2277, lng: 6.7735),
      LatLng(lat: 51.4508, lng: 7.0131),
    ],
    distanceMeters: 42100,
    durationSeconds: 10800,
    roadSharePercent: 8.5,
    cyclewaySharePercent: 71.2,
    pathSharePercent: 20.3,
    warnings: [
      'Eine komplett straßenfreie Route wurde nicht gefunden.',
    ],
    segments: [],
  );

  RouteRequest? lastRequest;

  @override
  Future<RouteResult> calculateRoute(RouteRequest request) async {
    lastRequest = request;
    return result;
  }
}

class _FailingRoutingService implements RoutingService {
  @override
  Future<RouteResult> calculateRoute(RouteRequest request) async {
    throw Exception('network unavailable');
  }
}

class _FakeNavigationService implements NavigationService {
  final locationController = StreamController<NavigationLocation>.broadcast();
  final headingController = StreamController<double?>.broadcast();
  NavigationLocation? currentLocation;

  @override
  Future<void> ensureLocationPermission() async {}

  @override
  Future<NavigationLocation> getCurrentLocation() async {
    return currentLocation ??
        const NavigationLocation(
          point: LatLng(lat: 51.2277, lng: 6.7735),
        );
  }

  @override
  Stream<NavigationLocation> getLocationStream() {
    return locationController.stream;
  }

  @override
  Stream<double?> getHeadingStream() {
    return headingController.stream;
  }

  void addLocation(NavigationLocation location) {
    locationController.add(location);
  }

  Future<void> dispose() async {
    await locationController.close();
    await headingController.close();
  }
}
