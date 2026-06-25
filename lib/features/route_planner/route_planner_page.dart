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
                          RouteStatsPanel(route: controller.route),
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
}
