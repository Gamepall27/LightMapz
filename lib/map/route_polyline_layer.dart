import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as map_lat_lng;

import '../routing/models/lat_lng.dart';

class RoutePolylineLayer extends StatelessWidget {
  const RoutePolylineLayer({
    required this.routeGeometry,
    required this.color,
    super.key,
  });

  final List<LatLng> routeGeometry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (routeGeometry.length < 2) {
      return const SizedBox.shrink();
    }

    final points = routeGeometry
        .map((point) => map_lat_lng.LatLng(point.lat, point.lng))
        .toList();

    return PolylineLayer(
      polylines: [
        Polyline(
          points: points,
          strokeWidth: 10,
          color: color.withValues(alpha: 0.24),
        ),
        Polyline(
          points: points,
          strokeWidth: 5,
          color: color,
        ),
      ],
    );
  }
}
