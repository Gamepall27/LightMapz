import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/features/route_planner/route_planner_page.dart';
import 'package:lightmapz/geocoding/geocoding_service.dart';
import 'package:lightmapz/geocoding/models/geocode_result.dart';
import 'package:lightmapz/routing/models/lat_lng.dart';
import 'package:lightmapz/routing/models/route_request.dart';
import 'package:lightmapz/routing/models/route_result.dart';
import 'package:lightmapz/routing/routing_service.dart';

void main() {
  group('RoutePlannerPage', () {
    testWidgets('calculates a route and displays returned route stats',
        (tester) async {
      final service = _PageTestRoutingService();

      await tester.pumpWidget(
        MaterialApp(
          home: RoutePlannerPage(
            routingService: service,
            geocodingService: _PageTestGeocodingService(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Route berechnen'), findsOneWidget);

      await tester.tap(find.text('Route berechnen'));
      await tester.pump();

      expect(service.callCount, 1);

      await tester.drag(find.byType(ListView), const Offset(0, -240));
      await tester.pump();

      expect(find.text('10.0 km'), findsOneWidget);
      expect(find.text('50 min'), findsOneWidget);
    });

    testWidgets('sends geocoded addresses and slider value to the service',
        (tester) async {
      final service = _PageTestRoutingService();

      await tester.pumpWidget(
        MaterialApp(
          home: RoutePlannerPage(
            routingService: service,
            geocodingService: _PageTestGeocodingService(),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('start_address_field')),
        'Start Test',
      );
      await tester.enterText(
        find.byKey(const Key('destination_address_field')),
        'Ziel Test',
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged?.call(75);
      await tester.pump();

      await tester.tap(find.text('Route berechnen'));
      await tester.pump();

      expect(service.lastRequest?.start, const LatLng(lat: 50.1, lng: 7.1));
      expect(service.lastRequest?.roadAvoidanceStrictness, 75);
    });
  });
}

class _PageTestGeocodingService implements GeocodingService {
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

class _PageTestRoutingService implements RoutingService {
  int callCount = 0;
  RouteRequest? lastRequest;

  @override
  Future<RouteResult> calculateRoute(RouteRequest request) async {
    callCount += 1;
    lastRequest = request;

    return const RouteResult(
      geometry: [
        LatLng(lat: 51.2277, lng: 6.7735),
        LatLng(lat: 51.4508, lng: 7.0131),
      ],
      distanceMeters: 10000,
      durationSeconds: 3000,
      roadSharePercent: 10,
      cyclewaySharePercent: 70,
      pathSharePercent: 20,
      warnings: [],
      segments: [],
    );
  }
}
