import 'lat_lng.dart';
import 'route_segment.dart';

class RouteResult {
  const RouteResult({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.roadSharePercent,
    required this.cyclewaySharePercent,
    required this.pathSharePercent,
    required this.warnings,
    required this.segments,
  });

  final List<LatLng> geometry;
  final double distanceMeters;
  final int durationSeconds;
  final double roadSharePercent;
  final double cyclewaySharePercent;
  final double pathSharePercent;
  final List<String> warnings;
  final List<RouteSegment> segments;

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    return RouteResult(
      geometry: (json['geometry'] as List<dynamic>? ?? const [])
          .map((point) => LatLng.fromJson(point as Map<String, dynamic>))
          .toList(),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      roadSharePercent: (json['roadSharePercent'] as num).toDouble(),
      cyclewaySharePercent: (json['cyclewaySharePercent'] as num).toDouble(),
      pathSharePercent: (json['pathSharePercent'] as num).toDouble(),
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((warning) => warning.toString())
          .toList(),
      segments: (json['segments'] as List<dynamic>? ?? const [])
          .map((segment) => RouteSegment.fromJson(
                segment as Map<String, dynamic>,
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'geometry': geometry.map((point) => point.toJson()).toList(),
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'roadSharePercent': roadSharePercent,
      'cyclewaySharePercent': cyclewaySharePercent,
      'pathSharePercent': pathSharePercent,
      'warnings': warnings,
      'segments': segments.map((segment) => segment.toJson()).toList(),
    };
  }
}
