import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/routing/mock_routing_service.dart';
import 'package:lightmapz/routing/models/lat_lng.dart';
import 'package:lightmapz/routing/models/route_request.dart';

void main() {
  group('MockRoutingService', () {
    test('returns a usable demo route between start and destination', () async {
      final service = MockRoutingService();

      final result = await service.calculateRoute(
        const RouteRequest(
          start: LatLng(lat: 51.2277, lng: 6.7735),
          destination: LatLng(lat: 51.4508, lng: 7.0131),
          roadAvoidanceStrictness: 50,
        ),
      );

      expect(result.geometry.first, const LatLng(lat: 51.2277, lng: 6.7735));
      expect(result.geometry.last, const LatLng(lat: 51.4508, lng: 7.0131));
      expect(result.geometry.length, greaterThanOrEqualTo(2));
      expect(result.distanceMeters, greaterThan(0));
      expect(result.durationSeconds, greaterThan(0));
      expect(result.segments, hasLength(3));
      expect(
        result.roadSharePercent +
            result.cyclewaySharePercent +
            result.pathSharePercent,
        closeTo(100, 0.001),
      );
    });

    test('reduces road share when strictness is higher', () async {
      final service = MockRoutingService();

      final relaxed = await service.calculateRoute(
        const RouteRequest(
          start: LatLng(lat: 51.2277, lng: 6.7735),
          destination: LatLng(lat: 51.4508, lng: 7.0131),
          roadAvoidanceStrictness: 0,
        ),
      );
      final strict = await service.calculateRoute(
        const RouteRequest(
          start: LatLng(lat: 51.2277, lng: 6.7735),
          destination: LatLng(lat: 51.4508, lng: 7.0131),
          roadAvoidanceStrictness: 100,
        ),
      );

      expect(strict.roadSharePercent, lessThan(relaxed.roadSharePercent));
      expect(strict.distanceMeters, greaterThan(relaxed.distanceMeters));
    });
  });
}
