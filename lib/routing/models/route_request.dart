import 'lat_lng.dart';

class RouteRequest {
  const RouteRequest({
    required this.start,
    required this.destination,
    required this.roadAvoidanceStrictness,
    this.preferForestWays = false,
    this.profile = 'bike',
  });

  final LatLng start;
  final LatLng destination;
  final String profile;

  /// 0 means normal/fast routing, 100 means avoid roads as strongly as possible.
  ///
  /// A future backend can translate this value into BRouter profile parameters,
  /// GraphHopper custom model weights, or a service-specific routing profile.
  final int roadAvoidanceStrictness;
  final bool preferForestWays;

  Map<String, dynamic> toJson() {
    return {
      'start': start.toJson(),
      'destination': destination.toJson(),
      'profile': profile,
      'roadAvoidanceStrictness': roadAvoidanceStrictness,
      'preferForestWays': preferForestWays,
    };
  }
}
