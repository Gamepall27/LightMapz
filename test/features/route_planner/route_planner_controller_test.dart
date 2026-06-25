import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/features/route_planner/route_planner_controller.dart';
import 'package:lightmapz/geocoding/geocoding_service.dart';
import 'package:lightmapz/geocoding/models/geocode_result.dart';
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

    test('passes current request to RoutingService and stores result', () async {
      final service = _SuccessfulRoutingService();
      final controller = RoutePlannerController(
        routingService: service,
        geocodingService: _FakeGeocodingService(),
      );
      addTearDown(controller.dispose);

      controller.updateStartAddress('Start Test');
      controller.updateDestinationAddress('Ziel Test');
      controller.updateRoadAvoidanceStrictness(75);

      await controller.calculateRoute();

      expect(service.lastRequest?.start, const LatLng(lat: 50.1, lng: 7.1));
      expect(
        service.lastRequest?.destination,
        const LatLng(lat: 50.2, lng: 7.2),
      );
      expect(service.lastRequest?.roadAvoidanceStrictness, 75);
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
  });
}

class _FakeGeocodingService implements GeocodingService {
  @override
  Future<List<GeocodeResult>> search(String query) async {
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
