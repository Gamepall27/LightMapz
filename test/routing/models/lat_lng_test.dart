import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/routing/models/lat_lng.dart';

void main() {
  group('LatLng', () {
    test('serializes to backend JSON shape', () {
      const point = LatLng(lat: 51.2277, lng: 6.7735);

      expect(point.toJson(), {
        'lat': 51.2277,
        'lng': 6.7735,
      });
    });

    test('deserializes numeric values from JSON', () {
      final point = LatLng.fromJson({
        'lat': 51,
        'lng': 6.7735,
      });

      expect(point.lat, 51.0);
      expect(point.lng, 6.7735);
    });

    test('compares points by value', () {
      expect(
        const LatLng(lat: 51.2277, lng: 6.7735),
        const LatLng(lat: 51.2277, lng: 6.7735),
      );
    });
  });
}
