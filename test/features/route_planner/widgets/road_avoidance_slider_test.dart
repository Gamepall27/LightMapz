import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/features/route_planner/widgets/road_avoidance_slider.dart';

void main() {
  group('RoadAvoidanceSlider', () {
    testWidgets('shows the selected strictness and explanation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoadAvoidanceSlider(
              value: 75,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Straßen vermeiden'), findsOneWidget);
      expect(find.text('75 %'), findsOneWidget);
      expect(find.text('Hauptstraßen massiv vermeiden'), findsOneWidget);
    });

    testWidgets('reports rounded slider values', (tester) async {
      int? selectedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoadAvoidanceSlider(
              value: 50,
              onChanged: (value) => selectedValue = value,
            ),
          ),
        ),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged?.call(74.6);

      expect(selectedValue, 75);
    });
  });
}
