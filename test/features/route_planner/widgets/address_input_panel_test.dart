import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/features/route_planner/route_planner_controller.dart';
import 'package:lightmapz/features/route_planner/widgets/address_input_panel.dart';
import 'package:lightmapz/geocoding/geocoding_service.dart';
import 'package:lightmapz/geocoding/models/geocode_result.dart';

void main() {
  group('AddressInputPanel', () {
    testWidgets(
        'uses current location button to set start field to eigener standort',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: AddressInputPanel(
              startAddress: '',
              destinationAddress: '',
              waypoints: const <RouteWaypoint>[],
              geocodingService: _FakeGeocodingService(),
              onStartAddressChanged: (_) {},
              onDestinationAddressChanged: (_) {},
              onAddWaypoint: () {},
              onWaypointAddressChanged: (_, __) {},
              onMoveWaypointUp: (_) {},
              onMoveWaypointDown: (_) {},
              onRemoveWaypoint: (_) {},
              onUseCurrentLocationAsStart: () async => true,
              onUseCurrentLocationAsDestination: () async => true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('start_current_location_button')));
      await tester.pumpAndSettle();

      final startField = tester.widget<TextField>(
        find.byKey(const Key('start_address_field')),
      );
      expect(startField.controller?.text, 'Eigener Standort');
    });

    testWidgets('shows an inline error when current location lookup fails',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: AddressInputPanel(
              startAddress: '',
              destinationAddress: '',
              waypoints: const <RouteWaypoint>[],
              geocodingService: _FakeGeocodingService(),
              onStartAddressChanged: (_) {},
              onDestinationAddressChanged: (_) {},
              onAddWaypoint: () {},
              onWaypointAddressChanged: (_, __) {},
              onMoveWaypointUp: (_) {},
              onMoveWaypointDown: (_) {},
              onRemoveWaypoint: (_) {},
              onUseCurrentLocationAsStart: () async => false,
              onUseCurrentLocationAsDestination: () async => true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('start_address_field')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('start_current_location_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Standort konnte nicht ermittelt werden.'),
        findsOneWidget,
      );
    });
  });
}

class _FakeGeocodingService implements GeocodingService {
  @override
  Future<List<GeocodeResult>> search(String query) async {
    return const [];
  }
}
