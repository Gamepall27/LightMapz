import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/routing/models/lat_lng.dart';
import 'package:lightmapz/routing/models/route_request.dart';

void main() {
  group('RouteRequest', () {
    test('uses bike as default profile and serializes the backend contract',
        () {
      const request = RouteRequest(
        start: LatLng(lat: 51.2277, lng: 6.7735),
        destination: LatLng(lat: 51.4508, lng: 7.0131),
        waypoints: [
          LatLng(lat: 51.3, lng: 6.9),
        ],
        roadAvoidanceStrictness: 75,
      );

      expect(request.toJson(), {
        'start': {
          'lat': 51.2277,
          'lng': 6.7735,
        },
        'destination': {
          'lat': 51.4508,
          'lng': 7.0131,
        },
        'waypoints': [
          {
            'lat': 51.3,
            'lng': 6.9,
          },
        ],
        'profile': 'bike',
        'roadAvoidanceStrictness': 75,
      });
    });

    test('serializes maximum-avoidance preferences when provided', () {
      const request = RouteRequest(
        start: LatLng(lat: 51.2277, lng: 6.7735),
        destination: LatLng(lat: 51.4508, lng: 7.0131),
        roadAvoidanceStrictness: 100,
        greenwayDetourRadiusKm: 12,
        minimumFieldWaySharePercent: 80,
      );

      expect(request.toJson(), containsPair('greenwayDetourRadiusKm', 12));
      expect(
        request.toJson(),
        containsPair('minimumFieldWaySharePercent', 80),
      );
    });
  });
}
