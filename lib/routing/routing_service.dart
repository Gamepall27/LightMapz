import 'models/route_request.dart';
import 'models/route_result.dart';

abstract class RoutingService {
  Future<RouteResult> calculateRoute(RouteRequest request);
}
