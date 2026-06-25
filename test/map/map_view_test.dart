import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/map/map_view.dart';
import 'package:lightmapz/routing/models/lat_lng.dart';

void main() {
  group('MapView', () {
    testWidgets('renders the OpenStreetMap view without throwing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 420,
              child: MapView(
                start: LatLng(lat: 51.2277, lng: 6.7735),
                destination: LatLng(lat: 51.4508, lng: 7.0131),
                waypoints: [
                  LatLng(lat: 51.3, lng: 6.9),
                ],
                selectedPoint: LatLng(lat: 51.35, lng: 6.95),
                currentLocation: LatLng(lat: 51.24, lng: 6.79),
                currentHeadingDegrees: 90,
                isNavigationActive: true,
                routeGeometry: [
                  LatLng(lat: 51.2277, lng: 6.7735),
                  LatLng(lat: 51.25, lng: 6.8),
                  LatLng(lat: 51.4508, lng: 7.0131),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MapView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports tapped map points', (tester) async {
      LatLng? selectedPoint;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 420,
              child: MapView(
                start: const LatLng(lat: 51.2277, lng: 6.7735),
                destination: const LatLng(lat: 51.4508, lng: 7.0131),
                waypoints: const [],
                selectedPoint: null,
                currentLocation: null,
                currentHeadingDegrees: null,
                isNavigationActive: false,
                routeGeometry: const [],
                onMapPointSelected: (point) {
                  selectedPoint = point;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(MapView));
      await tester.pump();

      expect(selectedPoint, isNotNull);
    });
  });
}
