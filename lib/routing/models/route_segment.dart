class RouteSegment {
  const RouteSegment({
    required this.distanceMeters,
    required this.surface,
    required this.wayType,
    required this.roadClass,
  });

  final double distanceMeters;
  final String surface;
  final String wayType;
  final String roadClass;

  factory RouteSegment.fromJson(Map<String, dynamic> json) {
    return RouteSegment(
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      surface: json['surface'] as String? ?? 'unknown',
      wayType: json['wayType'] as String? ?? 'unknown',
      roadClass: json['roadClass'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distanceMeters': distanceMeters,
      'surface': surface,
      'wayType': wayType,
      'roadClass': roadClass,
    };
  }
}
