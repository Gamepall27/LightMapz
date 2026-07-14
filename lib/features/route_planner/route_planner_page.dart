import 'package:flutter/material.dart';

import '../../export/gpx_export_service.dart';
import '../../export/gpx_file_picker_service.dart';
import '../../geocoding/geocoding_service.dart';
import '../../map/map_view.dart';
import '../../navigation/navigation_service.dart';
import '../../routing/models/lat_lng.dart';
import '../../routing/routing_service.dart';
import 'route_planner_controller.dart';
import 'widgets/address_input_panel.dart';
import 'widgets/navigation_status_panel.dart';
import 'widgets/road_avoidance_slider.dart';
import 'widgets/route_stats_panel.dart';

class RoutePlannerPage extends StatefulWidget {
  const RoutePlannerPage({
    required this.routingService,
    required this.geocodingService,
    this.navigationService = const DeviceNavigationService(),
    this.gpxExportService = const LocalGpxExportService(),
    this.gpxImportService = const LocalGpxExportService(),
    this.gpxFilePickerService = const PlatformGpxFilePickerService(),
    super.key,
  });

  final RoutingService routingService;
  final GeocodingService geocodingService;
  final NavigationService navigationService;
  final GpxExportService gpxExportService;
  final GpxImportService gpxImportService;
  final GpxFilePickerService gpxFilePickerService;

  @override
  State<RoutePlannerPage> createState() => _RoutePlannerPageState();
}

class _RoutePlannerPageState extends State<RoutePlannerPage> {
  late final RoutePlannerController controller;
  LatLng? selectedMapPoint;
  bool isExportingGpx = false;
  bool isImportingGpx = false;

  @override
  void initState() {
    super.initState();
    controller = RoutePlannerController(
      routingService: widget.routingService,
      geocodingService: widget.geocodingService,
      navigationService: widget.navigationService,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isNavigationActive = controller.isNavigationActive;

        return Scaffold(
          appBar: isNavigationActive
              ? null
              : AppBar(
                  title: const Text('LightMapz'),
                  actions: [
                    IconButton(
                      tooltip: 'GPX importieren',
                      onPressed: isImportingGpx ? null : _importGpx,
                      icon: isImportingGpx
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                    ),
                    IconButton(
                      tooltip: 'Einstellungen',
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings),
                    ),
                  ],
                ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: MapView(
                          start: controller.start,
                          destination: controller.destination,
                          waypoints: controller.waypoints
                              .map((waypoint) => waypoint.point)
                              .whereType<LatLng>()
                              .toList(),
                          selectedPoint: selectedMapPoint,
                          routeGeometry: controller.route?.geometry ?? const [],
                          currentLocation: controller.currentLocation,
                          currentHeadingDegrees:
                              controller.currentHeadingDegrees,
                          isNavigationActive: controller.isNavigationActive,
                          onMapPointSelected:
                              isNavigationActive ? null : _openMapPointActions,
                        ),
                      ),
                      if (controller.displayedNavigationStats != null)
                        Positioned(
                          left: 12,
                          top: 12,
                          right: 12,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: NavigationStatusPanel(
                              stats: controller.displayedNavigationStats!,
                              isNavigationActive: controller.isNavigationActive,
                            ),
                          ),
                        ),
                      if (controller.route != null)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: _NavigationStartButton(
                            isActive: controller.isNavigationActive,
                            isStarting: controller.isNavigationStarting,
                            onPressed: () {
                              if (controller.isNavigationActive) {
                                controller.stopNavigation();
                              } else {
                                controller.startNavigation();
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isNavigationActive)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                    ),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            AddressInputPanel(
                              startAddress: controller.startAddress,
                              destinationAddress: controller.destinationAddress,
                              waypoints: controller.waypoints,
                              geocodingService: widget.geocodingService,
                              onStartAddressChanged:
                                  controller.updateStartAddress,
                              onDestinationAddressChanged:
                                  controller.updateDestinationAddress,
                              onAddWaypoint: controller.addWaypoint,
                              onWaypointAddressChanged:
                                  controller.updateWaypointAddress,
                              onMoveWaypointUp: controller.moveWaypointUp,
                              onMoveWaypointDown: controller.moveWaypointDown,
                              onRemoveWaypoint: controller.removeWaypoint,
                              onUseCurrentLocationAsStart:
                                  controller.setStartToCurrentLocation,
                              onUseCurrentLocationAsDestination:
                                  controller.setDestinationToCurrentLocation,
                            ),
                            const SizedBox(height: 12),
                            RoadAvoidanceSlider(
                              value: controller.roadAvoidanceStrictness,
                              onChanged:
                                  controller.updateRoadAvoidanceStrictness,
                            ),
                            if (controller.roadAvoidanceStrictness == 100) ...[
                              const SizedBox(height: 12),
                              GreenwayDetourRadiusSlider(
                                value: controller.greenwayDetourRadiusKm,
                                onChanged:
                                    controller.updateGreenwayDetourRadiusKm,
                              ),
                              const SizedBox(height: 12),
                              MinimumFieldWayShareSlider(
                                value: controller.minimumFieldWaySharePercent,
                                onChanged: controller
                                    .updateMinimumFieldWaySharePercent,
                              ),
                            ],
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: controller.isLoading
                                  ? null
                                  : controller.calculateRoute,
                              icon: controller.isLoading
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.route),
                              label: const Text('Route berechnen'),
                            ),
                            if (controller.errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                controller.errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            if (controller.navigationErrorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                controller.navigationErrorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            RouteStatsPanel(
                              route: controller.route,
                              averageSpeedKmh: controller.averageSpeedKmh,
                              onExportGpx:
                                  controller.route == null ? null : _exportGpx,
                              isExporting: isExportingGpx,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMapPointActions(LatLng point) async {
    setState(() {
      selectedMapPoint = point;
    });

    final action = await showModalBottomSheet<_MapPointAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _MapPointActionsSheet(point: point);
      },
    );

    if (!mounted) {
      return;
    }

    if (action == _MapPointAction.start) {
      controller.setStartFromMap(point);
    } else if (action == _MapPointAction.waypoint) {
      controller.addWaypointFromMap(point);
    } else if (action == _MapPointAction.destination) {
      controller.setDestinationFromMap(point);
    }

    setState(() {
      selectedMapPoint = null;
    });
  }

  Future<void> _exportGpx() async {
    final route = controller.route;

    if (route == null || route.geometry.length < 2 || isExportingGpx) {
      return;
    }

    setState(() {
      isExportingGpx = true;
    });

    try {
      final exportResult = await widget.gpxExportService.exportRoute(
        GpxRouteDocument(
          name:
              '${controller.startAddress} nach ${controller.destinationAddress}',
          waypoints: [
            GpxWaypoint(
              name: controller.startAddress,
              point: controller.start,
            ),
            ...controller.waypoints
                .where((waypoint) => waypoint.point != null)
                .map(
                  (waypoint) => GpxWaypoint(
                    name: waypoint.address,
                    point: waypoint.point!,
                  ),
                ),
            GpxWaypoint(
              name: controller.destinationAddress,
              point: controller.destination,
            ),
          ],
          geometry: route.geometry,
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exportResult.path == null
                ? 'GPX exportiert: ${exportResult.filename}'
                : 'GPX exportiert: ${exportResult.path}',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GPX-Export fehlgeschlagen: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isExportingGpx = false;
        });
      }
    }
  }

  Future<void> _importGpx() async {
    if (isImportingGpx) {
      return;
    }

    final file = await widget.gpxFilePickerService.pickImportFile();

    if (!mounted || file == null) {
      return;
    }

    setState(() {
      isImportingGpx = true;
    });

    try {
      final document = await widget.gpxImportService.importRouteFromFile(file);
      controller.importGpxRoute(document);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GPX importiert: ${document.name}'),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GPX-Import fehlgeschlagen: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isImportingGpx = false;
        });
      }
    }
  }

  Future<void> _openSettings() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return _RoutePlannerSettingsDialog(
              averageSpeedKmh: controller.averageSpeedKmh,
              onAverageSpeedChanged: controller.updateAverageSpeedKmh,
            );
          },
        );
      },
    );
  }
}

class _NavigationStartButton extends StatelessWidget {
  const _NavigationStartButton({
    required this.isActive,
    required this.isStarting,
    required this.onPressed,
  });

  final bool isActive;
  final bool isStarting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const Key('navigation_start_button'),
      onPressed: isStarting ? null : onPressed,
      icon: isStarting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(isActive ? Icons.stop : Icons.navigation),
      label: Text(isActive ? 'Stoppen' : 'Starten'),
    );
  }
}

enum _MapPointAction {
  start,
  waypoint,
  destination,
}

class _MapPointActionsSheet extends StatelessWidget {
  const _MapPointActionsSheet({
    required this.point,
  });

  final LatLng point;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kartenpunkt verwenden',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${point.lat.toStringAsFixed(5)}, '
              '${point.lng.toStringAsFixed(5)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.trip_origin),
              title: const Text('Als Startpunkt'),
              onTap: () => Navigator.of(context).pop(_MapPointAction.start),
            ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Als Zwischenstopp'),
              onTap: () => Navigator.of(context).pop(_MapPointAction.waypoint),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Als Ziel'),
              onTap: () =>
                  Navigator.of(context).pop(_MapPointAction.destination),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePlannerSettingsDialog extends StatefulWidget {
  const _RoutePlannerSettingsDialog({
    required this.averageSpeedKmh,
    required this.onAverageSpeedChanged,
  });

  final double averageSpeedKmh;
  final ValueChanged<double> onAverageSpeedChanged;

  @override
  State<_RoutePlannerSettingsDialog> createState() =>
      _RoutePlannerSettingsDialogState();
}

class _RoutePlannerSettingsDialogState
    extends State<_RoutePlannerSettingsDialog> {
  late final TextEditingController speedController;
  late final FocusNode speedFocusNode;

  @override
  void initState() {
    super.initState();
    speedController = TextEditingController(
      text: _formatSpeed(widget.averageSpeedKmh),
    );
    speedFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _RoutePlannerSettingsDialog oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextText = _formatSpeed(widget.averageSpeedKmh);
    if (!speedFocusNode.hasFocus && speedController.text != nextText) {
      speedController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    }
  }

  @override
  void dispose() {
    speedController.dispose();
    speedFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Einstellungen'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_bike,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Durchschnittsgeschwindigkeit',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('average_speed_field'),
              controller: speedController,
              focusNode: speedFocusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Tempo',
                suffixText: 'km/h',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _updateFromText,
            ),
            const SizedBox(height: 12),
            Slider(
              key: const Key('average_speed_slider'),
              value: widget.averageSpeedKmh,
              min: 5,
              max: 45,
              divisions: 80,
              label: '${_formatSpeed(widget.averageSpeedKmh)} km/h',
              onChanged: widget.onAverageSpeedChanged,
            ),
            Text(
              'Die angezeigte Dauer wird aus Distanz und Tempo berechnet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }

  void _updateFromText(String value) {
    final normalized = value.replaceAll(',', '.');
    final parsed = double.tryParse(normalized);

    if (parsed != null) {
      widget.onAverageSpeedChanged(parsed);
    }
  }

  String _formatSpeed(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }

    return value.toStringAsFixed(1);
  }
}
