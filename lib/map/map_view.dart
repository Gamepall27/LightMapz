import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as map_lat_lng;

import '../routing/models/lat_lng.dart';
import 'route_polyline_layer.dart';

class MapView extends StatelessWidget {
  const MapView({
    required this.start,
    required this.destination,
    required this.routeGeometry,
    super.key,
  });

  final LatLng start;
  final LatLng destination;
  final List<LatLng> routeGeometry;

  @override
  Widget build(BuildContext context) {
    final allPoints = [
      start,
      destination,
      ...routeGeometry,
    ];
    final center = _centerOf(allPoints);

    return FlutterMap(
      key: ValueKey(
        '${start.lat},${start.lng}-${destination.lat},${destination.lng}-${routeGeometry.length}',
      ),
      options: MapOptions(
        initialCenter: _toMapLatLng(center),
        initialZoom: _initialZoomFor(allPoints),
        minZoom: 3,
        maxZoom: 19,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.lightmapz',
          maxNativeZoom: 19,
        ),
        RoutePolylineLayer(
          routeGeometry: routeGeometry,
          color: Theme.of(context).colorScheme.primary,
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _toMapLatLng(start),
              width: 44,
              height: 44,
              child: const _MapMarker(
                label: 'S',
                color: Color(0xFF1565C0),
              ),
            ),
            Marker(
              point: _toMapLatLng(destination),
              width: 44,
              height: 44,
              child: const _MapMarker(
                label: 'Z',
                color: Color(0xFFC62828),
              ),
            ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  LatLng _centerOf(List<LatLng> points) {
    final minLat = points.map((point) => point.lat).reduce(_min);
    final maxLat = points.map((point) => point.lat).reduce(_max);
    final minLng = points.map((point) => point.lng).reduce(_min);
    final maxLng = points.map((point) => point.lng).reduce(_max);

    return LatLng(
      lat: (minLat + maxLat) / 2,
      lng: (minLng + maxLng) / 2,
    );
  }

  double _initialZoomFor(List<LatLng> points) {
    final minLat = points.map((point) => point.lat).reduce(_min);
    final maxLat = points.map((point) => point.lat).reduce(_max);
    final minLng = points.map((point) => point.lng).reduce(_min);
    final maxLng = points.map((point) => point.lng).reduce(_max);
    final span = _max(maxLat - minLat, maxLng - minLng);

    if (span < 0.02) {
      return 14;
    }
    if (span < 0.08) {
      return 12;
    }
    if (span < 0.25) {
      return 10;
    }
    if (span < 0.8) {
      return 8;
    }

    return 6;
  }

  map_lat_lng.LatLng _toMapLatLng(LatLng point) {
    return map_lat_lng.LatLng(point.lat, point.lng);
  }

  double _min(double a, double b) {
    return a < b ? a : b;
  }

  double _max(double a, double b) {
    return a > b ? a : b;
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
