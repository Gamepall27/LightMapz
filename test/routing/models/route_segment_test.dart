import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/routing/models/route_segment.dart';

void main() {
  group('RouteSegment', () {
    test('deserializes complete segment JSON', () {
      final segment = RouteSegment.fromJson({
        'distanceMeters': 1200,
        'surface': 'asphalt',
        'wayType': 'cycleway',
        'roadClass': 'cycleway',
      });

      expect(segment.distanceMeters, 1200.0);
      expect(segment.surface, 'asphalt');
      expect(segment.wayType, 'cycleway');
      expect(segment.roadClass, 'cycleway');
    });

    test('uses unknown defaults for optional descriptive fields', () {
      final segment = RouteSegment.fromJson({
        'distanceMeters': 300,
      });

      expect(segment.surface, 'unknown');
      expect(segment.wayType, 'unknown');
      expect(segment.roadClass, 'unknown');
    });

    test('serializes to backend JSON shape', () {
      const segment = RouteSegment(
        distanceMeters: 1200,
        surface: 'asphalt',
        wayType: 'cycleway',
        roadClass: 'cycleway',
      );

      expect(segment.toJson(), {
        'distanceMeters': 1200.0,
        'surface': 'asphalt',
        'wayType': 'cycleway',
        'roadClass': 'cycleway',
      });
    });
  });
}
