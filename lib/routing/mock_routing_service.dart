import 'dart:math';

import 'models/lat_lng.dart';
import 'models/route_request.dart';
import 'models/route_result.dart';
import 'models/route_segment.dart';
import 'routing_service.dart';

class MockRoutingService implements RoutingService {
  @override
  Future<RouteResult> calculateRoute(RouteRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final routePoints = [
      request.start,
      ...request.waypoints,
      request.destination,
    ];
    final geometry = _buildDemoGeometry(routePoints);
    final directDistance = _estimateRouteDistanceMeters(routePoints);
    final detourFactor = 1 + request.roadAvoidanceStrictness / 180;
    final distanceMeters = directDistance * detourFactor;
    final durationSeconds = (distanceMeters / 3.9).round();

    final strictness = request.roadAvoidanceStrictness.toDouble();
    final roadShare = max(4.0, 38.0 - strictness * 0.34);
    final cyclewayShare = min(76.0, 34.0 + strictness * 0.42);
    final pathShare = max(0.0, 100.0 - roadShare - cyclewayShare);

    return RouteResult(
      geometry: geometry,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      roadSharePercent: roadShare,
      cyclewaySharePercent: cyclewayShare,
      pathSharePercent: pathShare,
      warnings: roadShare > 0
          ? const ['Eine komplett straßenfreie Route wurde nicht gefunden.']
          : const [],
      segments: [
        RouteSegment(
          distanceMeters: distanceMeters * cyclewayShare / 100,
          surface: 'asphalt',
          wayType: 'cycleway',
          roadClass: 'cycleway',
        ),
        RouteSegment(
          distanceMeters: distanceMeters * pathShare / 100,
          surface: 'compacted',
          wayType: 'path',
          roadClass: 'path',
        ),
        RouteSegment(
          distanceMeters: distanceMeters * roadShare / 100,
          surface: 'asphalt',
          wayType: 'residential',
          roadClass: 'local_road',
        ),
      ],
    );
  }

  List<LatLng> _buildDemoGeometry(List<LatLng> routePoints) {
    final geometry = <LatLng>[];

    for (var index = 0; index < routePoints.length - 1; index++) {
      final legGeometry = _buildDemoLegGeometry(
        routePoints[index],
        routePoints[index + 1],
      );

      if (geometry.isEmpty) {
        geometry.addAll(legGeometry);
      } else {
        geometry.addAll(legGeometry.skip(1));
      }
    }

    return geometry;
  }

  List<LatLng> _buildDemoLegGeometry(LatLng start, LatLng destination) {
    final midLat = (start.lat + destination.lat) / 2;
    final midLng = (start.lng + destination.lng) / 2;
    final latOffset = (destination.lng - start.lng) * 0.08;
    final lngOffset = (start.lat - destination.lat) * 0.08;

    return [
      start,
      LatLng(
        lat: start.lat * 0.7 + midLat * 0.3 + latOffset,
        lng: start.lng * 0.7 + midLng * 0.3 + lngOffset,
      ),
      LatLng(
        lat: midLat + latOffset,
        lng: midLng + lngOffset,
      ),
      LatLng(
        lat: destination.lat * 0.7 + midLat * 0.3 + latOffset,
        lng: destination.lng * 0.7 + midLng * 0.3 + lngOffset,
      ),
      destination,
    ];
  }

  double _estimateRouteDistanceMeters(List<LatLng> routePoints) {
    var distanceMeters = 0.0;

    for (var index = 0; index < routePoints.length - 1; index++) {
      distanceMeters += _estimateDistanceMeters(
        routePoints[index],
        routePoints[index + 1],
      );
    }

    return distanceMeters;
  }

  double _estimateDistanceMeters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _toRadians(b.lat - a.lat);
    final dLng = _toRadians(b.lng - a.lng);
    final lat1 = _toRadians(a.lat);
    final lat2 = _toRadians(b.lat);

    final haversine = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return earthRadiusMeters * 2 * atan2(sqrt(haversine), sqrt(1 - haversine));
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
}
