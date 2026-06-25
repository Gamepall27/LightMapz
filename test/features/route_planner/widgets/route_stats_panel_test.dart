import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/features/route_planner/widgets/route_stats_panel.dart';
import 'package:lightmapz/routing/models/lat_lng.dart';
import 'package:lightmapz/routing/models/route_result.dart';

void main() {
  group('RouteStatsPanel', () {
    testWidgets('renders nothing when no route exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RouteStatsPanel(route: null),
          ),
        ),
      );

      expect(find.text('Routendaten'), findsNothing);
    });

    testWidgets('renders distance, duration, shares, and warnings',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RouteStatsPanel(
              route: RouteResult(
                geometry: [
                  LatLng(lat: 51.2277, lng: 6.7735),
                  LatLng(lat: 51.4508, lng: 7.0131),
                ],
                distanceMeters: 42100,
                durationSeconds: 10800,
                roadSharePercent: 8.5,
                cyclewaySharePercent: 71.2,
                pathSharePercent: 20.3,
                warnings: [
                  'Eine komplett straßenfreie Route wurde nicht gefunden.',
                ],
                segments: [],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Routendaten'), findsOneWidget);
      expect(find.text('42.1 km'), findsOneWidget);
      expect(find.text('3 h 0 min'), findsOneWidget);
      expect(find.text('8.5 %'), findsOneWidget);
      expect(find.text('71.2 %'), findsOneWidget);
      expect(find.text('20.3 %'), findsOneWidget);
      expect(
        find.text('Eine komplett straßenfreie Route wurde nicht gefunden.'),
        findsOneWidget,
      );
    });
  });
}
