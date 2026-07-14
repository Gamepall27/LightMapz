import 'lat_lng.dart';

class RouteRequest {
  const RouteRequest({
    required this.start,
    required this.destination,
    required this.roadAvoidanceStrictness,
    this.waypoints = const [],
    this.greenwayDetourRadiusKm,
    this.minimumFieldWaySharePercent,
    this.profile = 'bike',
  });

  final LatLng start;
  final LatLng destination;
  final List<LatLng> waypoints;
  final String profile;

  /// 0 means normal/fast routing, 100 means avoid roads as strongly as possible.
  ///
  /// A future backend can translate this value into BRouter profile parameters,
  /// GraphHopper custom model weights, or a service-specific routing profile.
  final int roadAvoidanceStrictness;
  final int? greenwayDetourRadiusKm;
  final int? minimumFieldWaySharePercent;

  Map<String, dynamic> toJson() {
    return {
      'start': start.toJson(),
      'destination': destination.toJson(),
      'waypoints': waypoints.map((point) => point.toJson()).toList(),
      'profile': profile,
      'roadAvoidanceStrictness': roadAvoidanceStrictness,
      if (greenwayDetourRadiusKm != null)
        'greenwayDetourRadiusKm': greenwayDetourRadiusKm,
      if (minimumFieldWaySharePercent != null)
        'minimumFieldWaySharePercent': minimumFieldWaySharePercent,
    };
  }
}
