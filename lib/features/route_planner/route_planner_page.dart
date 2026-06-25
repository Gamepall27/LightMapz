import 'package:flutter/material.dart';

import '../../geocoding/geocoding_service.dart';
import '../../map/map_view.dart';
import '../../routing/routing_service.dart';
import 'route_planner_controller.dart';
import 'widgets/address_input_panel.dart';
import 'widgets/road_avoidance_slider.dart';
import 'widgets/route_stats_panel.dart';

class RoutePlannerPage extends StatefulWidget {
  const RoutePlannerPage({
    required this.routingService,
    required this.geocodingService,
    super.key,
  });

  final RoutingService routingService;
  final GeocodingService geocodingService;

  @override
  State<RoutePlannerPage> createState() => _RoutePlannerPageState();
}

class _RoutePlannerPageState extends State<RoutePlannerPage> {
  late final RoutePlannerController controller;

  @override
  void initState() {
    super.initState();
    controller = RoutePlannerController(
      routingService: widget.routingService,
      geocodingService: widget.geocodingService,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LightMapz'),
        actions: [
          IconButton(
            tooltip: 'Einstellungen',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Column(
              children: [
                Expanded(
                  child: MapView(
                    start: controller.start,
                    destination: controller.destination,
                    routeGeometry: controller.route?.geometry ?? const [],
                  ),
                ),
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
                            geocodingService: widget.geocodingService,
                            onStartAddressChanged:
                                controller.updateStartAddress,
                            onDestinationAddressChanged:
                                controller.updateDestinationAddress,
                          ),
                          const SizedBox(height: 12),
                          RoadAvoidanceSlider(
                            value: controller.roadAvoidanceStrictness,
                            onChanged: controller.updateRoadAvoidanceStrictness,
                          ),
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
                          const SizedBox(height: 12),
                          RouteStatsPanel(
                            route: controller.route,
                            averageSpeedKmh: controller.averageSpeedKmh,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
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
              preferForestWays: controller.preferForestWays,
              onAverageSpeedChanged: controller.updateAverageSpeedKmh,
              onPreferForestWaysChanged: controller.updatePreferForestWays,
            );
          },
        );
      },
    );
  }
}

class _RoutePlannerSettingsDialog extends StatefulWidget {
  const _RoutePlannerSettingsDialog({
    required this.averageSpeedKmh,
    required this.preferForestWays,
    required this.onAverageSpeedChanged,
    required this.onPreferForestWaysChanged,
  });

  final double averageSpeedKmh;
  final bool preferForestWays;
  final ValueChanged<double> onAverageSpeedChanged;
  final ValueChanged<bool> onPreferForestWaysChanged;

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
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('prefer_forest_ways_checkbox'),
              value: widget.preferForestWays,
              onChanged: (value) {
                widget.onPreferForestWaysChanged(value ?? false);
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Waldwege bevorzugen'),
              subtitle: const Text('Weniger straßenbegleitende Wege'),
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
