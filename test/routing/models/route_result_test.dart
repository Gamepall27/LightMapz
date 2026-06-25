import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/routing/models/lat_lng.dart';
import 'package:lightmapz/routing/models/route_result.dart';
import 'package:lightmapz/routing/models/route_segment.dart';

void main() {
  group('RouteResult', () {
    test('deserializes the prepared backend response', () {
      final result = RouteResult.fromJson({
        'geometry': [
          {'lat': 51.2277, 'lng': 6.7735},
          {'lat': 51.25, 'lng': 6.8},
          {'lat': 51.4508, 'lng': 7.0131},
        ],
        'distanceMeters': 42100,
        'durationSeconds': 10800,
        'roadSharePercent': 8.5,
        'cyclewaySharePercent': 71.2,
        'pathSharePercent': 20.3,
        'warnings': [
          'Eine komplett straßenfreie Route wurde nicht gefunden.',
        ],
        'segments': [
          {
            'distanceMeters': 1200,
            'surface': 'asphalt',
            'wayType': 'cycleway',
            'roadClass': 'cycleway',
          },
        ],
      });

      expect(result.geometry, hasLength(3));
      expect(result.geometry.first, const LatLng(lat: 51.2277, lng: 6.7735));
      expect(result.distanceMeters, 42100.0);
      expect(result.durationSeconds, 10800);
      expect(result.roadSharePercent, 8.5);
      expect(result.cyclewaySharePercent, 71.2);
      expect(result.pathSharePercent, 20.3);
      expect(result.warnings, hasLength(1));
      expect(result.segments.single.wayType, 'cycleway');
    });

    test('serializes nested geometry and segments', () {
      const result = RouteResult(
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
        segments: [
          RouteSegment(
            distanceMeters: 1200,
            surface: 'asphalt',
            wayType: 'cycleway',
            roadClass: 'cycleway',
          ),
        ],
      );

      expect(result.toJson(), {
        'geometry': [
          {'lat': 51.2277, 'lng': 6.7735},
          {'lat': 51.4508, 'lng': 7.0131},
        ],
        'distanceMeters': 42100.0,
        'durationSeconds': 10800,
        'roadSharePercent': 8.5,
        'cyclewaySharePercent': 71.2,
        'pathSharePercent': 20.3,
        'warnings': [
          'Eine komplett straßenfreie Route wurde nicht gefunden.',
        ],
        'segments': [
          {
            'distanceMeters': 1200.0,
            'surface': 'asphalt',
            'wayType': 'cycleway',
            'roadClass': 'cycleway',
          },
        ],
      });
    });
  });
}
