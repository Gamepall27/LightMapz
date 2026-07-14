import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/features/route_planner/route_planner_page.dart';
import 'package:lightmapz/geocoding/geocoding_service.dart';
import 'package:lightmapz/geocoding/models/geocode_result.dart';
import 'package:lightmapz/navigation/navigation_service.dart';
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

      await _tapCalculateRoute(tester);

      expect(service.callCount, 1);

      await tester.drag(find.byType(ListView), const Offset(0, -240));
      await tester.pump();

      expect(find.text('10.0 km'), findsWidgets);
      expect(find.text('33 min'), findsWidgets);
      expect(find.text('18 km/h'), findsOneWidget);
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
      await tester.pump(const Duration(milliseconds: 350));

      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged?.call(75);
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -280));
      await tester.pump();
      await tester.tap(find.text('Route berechnen'));
      await tester.pump();

      expect(service.lastRequest?.start, const LatLng(lat: 50.1, lng: 7.1));
      expect(service.lastRequest?.roadAvoidanceStrictness, 75);
    });

    testWidgets('shows detour radius slider at maximum avoidance and sends it',
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

      expect(
          find.byKey(const Key('greenway_detour_radius_slider')), findsNothing);

      final roadSlider = tester.widget<Slider>(find.byType(Slider));
      roadSlider.onChanged?.call(100);
      await tester.pump();

      expect(find.byKey(const Key('greenway_detour_radius_slider')),
          findsOneWidget);

      final radiusSlider = tester.widget<Slider>(
        find.byKey(const Key('greenway_detour_radius_slider')),
      );
      radiusSlider.onChanged?.call(12);
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pump();
      expect(find.byKey(const Key('minimum_field_way_share_slider')),
          findsOneWidget);

      final minimumShareSlider = tester.widget<Slider>(
        find.byKey(const Key('minimum_field_way_share_slider')),
      );
      minimumShareSlider.onChanged?.call(80);
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pump();
      await tester.tap(find.text('Route berechnen'));
      await tester.pump();

      expect(service.lastRequest?.roadAvoidanceStrictness, 100);
      expect(service.lastRequest?.greenwayDetourRadiusKm, 12);
      expect(service.lastRequest?.minimumFieldWaySharePercent, 80);
    });

    testWidgets('adds a waypoint and sends it to the service', (tester) async {
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

      await tester.tap(find.byKey(const Key('add_waypoint_button')));
      await tester.pump();

      expect(find.byKey(const Key('waypoint_waypoint_1_address_field')),
          findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('waypoint_waypoint_1_address_field')),
        'Zwischenstopp Test',
      );
      await tester.pump(const Duration(milliseconds: 350));

      await tester.drag(find.byType(ListView), const Offset(0, -280));
      await tester.pump();
      await tester.tap(find.text('Route berechnen'));
      await tester.pump();

      expect(service.lastRequest?.waypoints, [
        const LatLng(lat: 50.15, lng: 7.15),
      ]);
    });

    testWidgets('shows address suggestions and fills the selected suggestion',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoutePlannerPage(
            routingService: _PageTestRoutingService(),
            geocodingService: _PageTestGeocodingService(),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('start_address_field')),
        'Düs',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text('Düsseldorf Hauptbahnhof'), findsOneWidget);
      expect(find.text('Düsseldorf Altstadt'), findsOneWidget);

      await tester.tap(find.text('Düsseldorf Altstadt'));
      await tester.pump();

      final startField = tester.widget<TextField>(
        find.byKey(const Key('start_address_field')),
      );

      expect(startField.controller?.text, 'Düsseldorf Altstadt');
      expect(find.byKey(const Key('start_address_suggestions')), findsNothing);
    });

    testWidgets('shows current location suggestion for an empty start field',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoutePlannerPage(
            routingService: _PageTestRoutingService(),
            geocodingService: _PageTestGeocodingService(),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('start_address_field')),
        '',
      );
      await tester.tap(find.byKey(const Key('start_address_field')));
      await tester.pump();

      expect(
        find.byKey(const Key('start_current_location_suggestion')),
        findsOneWidget,
      );
      expect(find.text('Eigener Standort'), findsOneWidget);
    });

    testWidgets(
        'uses the current location suggestion as the resolved start point',
        (tester) async {
      final service = _PageTestRoutingService();
      final navigationService = _PageTestNavigationService()
        ..currentLocation = const NavigationLocation(
          point: LatLng(lat: 51.5123, lng: 7.4567),
          headingDegrees: 15,
        );
      addTearDown(navigationService.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: RoutePlannerPage(
            routingService: service,
            geocodingService: _PageTestGeocodingService(),
            navigationService: navigationService,
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('start_address_field')),
        '',
      );
      await tester.tap(find.byKey(const Key('start_address_field')));
      await tester.pump();
      await tester
          .tap(find.byKey(const Key('start_current_location_suggestion')));
      await tester.pumpAndSettle();

      expect(find.text('Eigener Standort'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -280));
      await tester.pump();
      await tester.tap(find.text('Route berechnen'));
      await tester.pump();

      expect(
        service.lastRequest?.start,
        const LatLng(lat: 51.5123, lng: 7.4567),
      );
    });

    testWidgets('hides planner controls while navigation is active',
        (tester) async {
      final navigationService = _PageTestNavigationService();
      addTearDown(navigationService.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: RoutePlannerPage(
            routingService: _PageTestRoutingService(),
            geocodingService: _PageTestGeocodingService(),
            navigationService: navigationService,
          ),
        ),
      );
      await tester.pump();

      await _tapCalculateRoute(tester);
      await tester.tap(find.text('Starten'));
      await tester.pump();

      expect(find.text('Adressen'), findsNothing);
      expect(find.text('Route berechnen'), findsNothing);
      expect(find.byTooltip('Einstellungen'), findsNothing);
      expect(find.text('Stoppen'), findsOneWidget);
      expect(find.byKey(const Key('navigation_status_panel')), findsOneWidget);
    });

    testWidgets('opens settings and recalculates duration from average speed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoutePlannerPage(
            routingService: _PageTestRoutingService(),
            geocodingService: _PageTestGeocodingService(),
          ),
        ),
      );
      await tester.pump();

      await _tapCalculateRoute(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -240));
      await tester.pump();

      expect(find.text('33 min'), findsWidgets);

      await tester.tap(find.byTooltip('Einstellungen'));
      await tester.pumpAndSettle();

      expect(find.text('Einstellungen'), findsOneWidget);
      expect(find.text('Durchschnittsgeschwindigkeit'), findsOneWidget);
      expect(find.text('Waldwege bevorzugen'), findsNothing);

      await tester.enterText(
          find.byKey(const Key('average_speed_field')), '20');
      await tester.pump();

      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();

      expect(find.text('30 min'), findsWidgets);
      expect(find.text('20 km/h'), findsOneWidget);
    });
  });
}

Future<void> _tapCalculateRoute(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -220));
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Route berechnen'));
  await tester.pump();
}

class _PageTestGeocodingService implements GeocodingService {
  @override
  Future<List<GeocodeResult>> search(String query) async {
    if (query.contains('Düs')) {
      return const [
        GeocodeResult(
          label: 'Düsseldorf Hauptbahnhof',
          point: LatLng(lat: 51.2202, lng: 6.792),
        ),
        GeocodeResult(
          label: 'Düsseldorf Altstadt',
          point: LatLng(lat: 51.2277, lng: 6.7735),
        ),
      ];
    }

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

class _PageTestNavigationService implements NavigationService {
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
          headingDegrees: 25,
          speedMetersPerSecond: 5,
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

  Future<void> dispose() async {
    await locationController.close();
    await headingController.close();
  }
}
