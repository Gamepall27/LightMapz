import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/app.dart';

void main() {
  group('LightMapzApp', () {
    testWidgets('starts on the route planner screen', (tester) async {
      await tester.pumpWidget(const LightMapzApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('LightMapz'), findsOneWidget);
      expect(find.text('Route berechnen'), findsOneWidget);
      expect(find.text('Straßen vermeiden'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });
  });
}
