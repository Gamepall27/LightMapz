import 'package:flutter/material.dart';

import 'export/gpx_export_service.dart';
import 'features/route_planner/route_planner_page.dart';
import 'geocoding/http_geocoding_service.dart';
import 'routing/http_routing_service.dart';

class LightMapzApp extends StatelessWidget {
  const LightMapzApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiBaseUrl = Uri.parse(
      const String.fromEnvironment(
        'LIGHTMAPZ_API_BASE_URL',
        defaultValue: 'http://127.0.0.1:3000',
      ),
    );

    return MaterialApp(
      title: 'LightMapz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: RoutePlannerPage(
        routingService: HttpRoutingService(baseUrl: apiBaseUrl),
        geocodingService: HttpGeocodingService(baseUrl: apiBaseUrl),
        gpxExportService: const LocalGpxExportService(),
      ),
    );
  }
}
