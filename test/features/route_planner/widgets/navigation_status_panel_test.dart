import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/features/route_planner/route_planner_controller.dart';
import 'package:lightmapz/features/route_planner/widgets/navigation_status_panel.dart';

void main() {
  group('NavigationStatusPanel', () {
    testWidgets('shows arrival time, duration and remaining distance',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavigationStatusPanel(
              stats: NavigationStats(
                remainingDistanceMeters: 12500,
                remainingDurationSeconds: 3900,
                estimatedArrivalTime: DateTime(2026, 6, 25, 15, 8),
                nextInstruction: const NavigationInstruction(
                  text: 'Rechts abbiegen',
                  distanceMeters: 180,
                ),
              ),
              isNavigationActive: true,
            ),
          ),
        ),
      );

      expect(find.text('Ankunft'), findsOneWidget);
      expect(find.text('15:08'), findsOneWidget);
      expect(find.text('Dauer'), findsOneWidget);
      expect(find.text('1 h 5 min'), findsOneWidget);
      expect(find.text('Distanz'), findsOneWidget);
      expect(find.text('12.5 km'), findsOneWidget);
      expect(find.text('180 m: Rechts abbiegen'), findsOneWidget);
      expect(find.byIcon(Icons.navigation), findsOneWidget);
    });
  });
}
