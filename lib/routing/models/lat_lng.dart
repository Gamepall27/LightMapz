class LatLng {
  const LatLng({
    required this.lat,
    required this.lng,
  });

  final double lat;
  final double lng;

  factory LatLng.fromJson(Map<String, dynamic> json) {
    return LatLng(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
    };
  }

  @override
  String toString() {
    return 'LatLng(lat: $lat, lng: $lng)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LatLng && other.lat == lat && other.lng == lng;
  }

  @override
  int get hashCode {
    return Object.hash(lat, lng);
  }
}
