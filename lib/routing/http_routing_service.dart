import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/route_request.dart';
import 'models/route_result.dart';
import 'routing_service.dart';

class HttpRoutingService implements RoutingService {
  const HttpRoutingService({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  final Uri baseUrl;
  final http.Client? _httpClient;

  @override
  Future<RouteResult> calculateRoute(RouteRequest request) async {
    final client = _httpClient ?? http.Client();

    try {
      final routeUri = baseUrl.replace(path: '/route');
      final response = await client.post(
        routeUri,
        headers: {'content-type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RoutingHttpException(
          statusCode: response.statusCode,
          body: response.body,
        );
      }

      return RouteResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } finally {
      if (_httpClient == null) {
        client.close();
      }
    }
  }
}

class RoutingHttpException implements Exception {
  const RoutingHttpException({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;

  @override
  String toString() {
    return 'RoutingHttpException(statusCode: $statusCode, body: $body)';
  }
}
