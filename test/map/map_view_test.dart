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
  });
}
