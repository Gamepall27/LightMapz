import '../../routing/models/lat_lng.dart';

class GeocodeResult {
  const GeocodeResult({
    required this.label,
    required this.point,
  });

  final String label;
  final LatLng point;

  factory GeocodeResult.fromJson(Map<String, dynamic> json) {
    return GeocodeResult(
      label: json['label'] as String? ?? 'Unbekannter Ort',
      point: LatLng.fromJson(json['point'] as Map<String, dynamic>),
    );
  }
}
