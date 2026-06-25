import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' as map_lat_lng;
import 'package:lightmapz/map/route_polyline_layer.dart';
import 'package:lightmapz/routing/models/lat_lng.dart';

void main() {
  group('RoutePolylineLayer', () {
    testWidgets('renders nothing for fewer than two route points',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoutePolylineLayer(
              routeGeometry: [
                LatLng(lat: 51.2277, lng: 6.7735),
              ],
              color: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byType(PolylineLayer), findsNothing);
    });

    testWidgets('renders two polylines for halo and route stroke',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlutterMap(
              options: MapOptions(
                initialCenter: map_lat_lng.LatLng(51.3, 6.8),
                initialZoom: 10,
              ),
              children: [
                RoutePolylineLayer(
                  routeGeometry: [
                    LatLng(lat: 51.2277, lng: 6.7735),
                    LatLng(lat: 51.4508, lng: 7.0131),
                  ],
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ),
      );

      final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));

      expect(layer.polylines, hasLength(2));
      expect(layer.polylines.first.strokeWidth, 10);
      expect(layer.polylines.last.strokeWidth, 5);
    });
  });
}
