import 'package:flutter/foundation.dart';

import '../../geocoding/geocoding_service.dart';
import '../../routing/models/lat_lng.dart';
import '../../routing/models/route_request.dart';
import '../../routing/models/route_result.dart';
import '../../routing/routing_service.dart';

class RoutePlannerController extends ChangeNotifier {
  RoutePlannerController({
    required RoutingService routingService,
    required GeocodingService geocodingService,
  })  : _routingService = routingService,
        _geocodingService = geocodingService;

  final RoutingService _routingService;
  final GeocodingService _geocodingService;

  LatLng start = const LatLng(lat: 51.2277, lng: 6.7735);
  LatLng destination = const LatLng(lat: 51.4508, lng: 7.0131);
  String startAddress = 'Kohlmeisenweg 18, 58507 Lüdenscheid';
  String destinationAddress = 'Homertturm, 58518 Lüdenscheid';
  int roadAvoidanceStrictness = 50;
  double averageSpeedKmh = 18;
  bool preferForestWays = false;

  RouteResult? route;
  bool isLoading = false;
  String? errorMessage;
  bool _isDisposed = false;

  void updateStartAddress(String value) {
    startAddress = value;
    route = null;
    errorMessage = null;
    notifyListeners();
  }

  void updateDestinationAddress(String value) {
    destinationAddress = value;
    route = null;
    errorMessage = null;
    notifyListeners();
  }

  void updateRoadAvoidanceStrictness(int value) {
    roadAvoidanceStrictness = value.clamp(0, 100).toInt();
    route = null;
    errorMessage = null;
    notifyListeners();
  }

  void updateAverageSpeedKmh(double value) {
    averageSpeedKmh = value.clamp(5, 45).toDouble();
    errorMessage = null;
    notifyListeners();
  }

  void updatePreferForestWays(bool value) {
    preferForestWays = value;
    route = null;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> calculateRoute() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final resolvedStart = await _resolveAddress(startAddress, 'Startadresse');
      final resolvedDestination = await _resolveAddress(
        destinationAddress,
        'Zieladresse',
      );

      start = resolvedStart;
      destination = resolvedDestination;
      route = await _routingService.calculateRoute(
        RouteRequest(
          start: resolvedStart,
          destination: resolvedDestination,
          roadAvoidanceStrictness: roadAvoidanceStrictness,
          preferForestWays: preferForestWays,
        ),
      );
    } on Exception catch (error) {
      errorMessage = 'Die Route konnte nicht berechnet werden: $error';
    } finally {
      isLoading = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<LatLng> _resolveAddress(String address, String fieldName) async {
    final trimmed = address.trim();

    if (trimmed.length < 3) {
      throw Exception('$fieldName ist zu kurz.');
    }

    final results = await _geocodingService.search(trimmed);

    if (results.isEmpty) {
      throw Exception('$fieldName wurde nicht gefunden.');
    }

    return results.first.point;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
