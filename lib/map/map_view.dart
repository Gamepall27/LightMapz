import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as map_lat_lng;

import '../routing/models/lat_lng.dart';
import 'route_polyline_layer.dart';

class MapView extends StatefulWidget {
  const MapView({
    required this.start,
    required this.destination,
    required this.waypoints,
    required this.selectedPoint,
    required this.routeGeometry,
    required this.currentLocation,
    required this.currentHeadingDegrees,
    required this.isNavigationActive,
    this.onMapPointSelected,
    super.key,
  });

  final LatLng start;
  final LatLng destination;
  final List<LatLng> waypoints;
  final LatLng? selectedPoint;
  final List<LatLng> routeGeometry;
  final LatLng? currentLocation;
  final double? currentHeadingDegrees;
  final bool isNavigationActive;
  final ValueChanged<LatLng>? onMapPointSelected;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static const _navigationZoom = 16.5;

  final MapController mapController = MapController();

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isNavigationActive &&
        widget.currentLocation != null &&
        (widget.currentLocation != oldWidget.currentLocation ||
            widget.currentHeadingDegrees != oldWidget.currentHeadingDegrees ||
            !oldWidget.isNavigationActive)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _followCurrentLocation();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPoints = [
      widget.start,
      ...widget.waypoints,
      widget.destination,
      if (widget.selectedPoint != null) widget.selectedPoint!,
      if (widget.currentLocation != null) widget.currentLocation!,
      ...widget.routeGeometry,
    ];
    final center = widget.isNavigationActive && widget.currentLocation != null
        ? widget.currentLocation!
        : _centerOf(allPoints);
    final initialRotation = widget.isNavigationActive
        ? widget.currentHeadingDegrees ?? 0
        : 0.0;

    return FlutterMap(
      mapController: mapController,
      key: ValueKey(
        '${widget.start.lat},${widget.start.lng}-'
        '${widget.destination.lat},${widget.destination.lng}-'
        '${widget.waypoints.length}-'
        '${widget.selectedPoint?.lat},${widget.selectedPoint?.lng}-'
        '${_routeGeometrySignature(widget.routeGeometry)}',
      ),
      options: MapOptions(
        initialCenter: _toMapLatLng(center),
        initialZoom: widget.isNavigationActive
            ? _navigationZoom
            : _initialZoomFor(allPoints),
        initialRotation: initialRotation,
        minZoom: 3,
        maxZoom: 19,
        onTap: (_, point) => _selectMapPoint(point),
        onLongPress: (_, point) => _selectMapPoint(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.lightmapz',
          maxNativeZoom: 19,
        ),
        RoutePolylineLayer(
          routeGeometry: widget.routeGeometry,
          color: Theme.of(context).colorScheme.primary,
        ),
        MarkerLayer(
          rotate: true,
          markers: [
            Marker(
              point: _toMapLatLng(widget.start),
              width: 44,
              height: 44,
              child: const _MapMarker(
                label: 'S',
                color: Color(0xFF1565C0),
              ),
            ),
            for (var index = 0; index < widget.waypoints.length; index++)
              Marker(
                point: _toMapLatLng(widget.waypoints[index]),
                width: 44,
                height: 44,
                child: _MapMarker(
                  label: '${index + 1}',
                  color: const Color(0xFF2E7D32),
                ),
              ),
            Marker(
              point: _toMapLatLng(widget.destination),
              width: 44,
              height: 44,
              child: const _MapMarker(
                label: 'Z',
                color: Color(0xFFC62828),
              ),
            ),
            if (widget.selectedPoint != null)
              Marker(
                point: _toMapLatLng(widget.selectedPoint!),
                width: 48,
                height: 48,
                child: const _MapMarker(
                  label: '+',
                  color: Color(0xFF6A1B9A),
                ),
              ),
          ],
        ),
        if (widget.currentLocation != null)
          MarkerLayer(
            rotate: true,
            markers: [
              Marker(
                point: _toMapLatLng(widget.currentLocation!),
                width: 52,
                height: 52,
                child: _CurrentLocationMarker(
                  hasHeading: widget.currentHeadingDegrees != null,
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

  void _followCurrentLocation() {
    final location = widget.currentLocation;

    if (location == null) {
      return;
    }

    try {
      final zoom = mapController.camera.zoom < _navigationZoom
          ? _navigationZoom
          : mapController.camera.zoom;
      mapController.moveAndRotate(
        _toMapLatLng(location),
        zoom,
        widget.currentHeadingDegrees ?? mapController.camera.rotation,
      );
    } catch (_) {
      return;
    }
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

  void _selectMapPoint(map_lat_lng.LatLng point) {
    widget.onMapPointSelected?.call(
      LatLng(lat: point.latitude, lng: point.longitude),
    );
  }

  String _routeGeometrySignature(List<LatLng> geometry) {
    if (geometry.isEmpty) {
      return 'empty';
    }

    final first = geometry.first;
    final last = geometry.last;
    final midpoint = geometry[geometry.length ~/ 2];

    return '${geometry.length}-'
        '${first.lat.toStringAsFixed(5)},${first.lng.toStringAsFixed(5)}-'
        '${midpoint.lat.toStringAsFixed(5)},${midpoint.lng.toStringAsFixed(5)}-'
        '${last.lat.toStringAsFixed(5)},${last.lng.toStringAsFixed(5)}';
  }

  double _min(double a, double b) {
    return a < b ? a : b;
  }

  double _max(double a, double b) {
    return a > b ? a : b;
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker({
    required this.hasHeading,
  });

  final bool hasHeading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        hasHeading ? Icons.navigation : Icons.my_location,
        color: Colors.white,
        size: 24,
      ),
    );
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
