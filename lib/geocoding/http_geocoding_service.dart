import 'dart:convert';

import 'package:http/http.dart' as http;

import 'geocoding_service.dart';
import 'models/geocode_result.dart';

class HttpGeocodingService implements GeocodingService {
  const HttpGeocodingService({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  final Uri baseUrl;
  final http.Client? _httpClient;

  @override
  Future<List<GeocodeResult>> search(String query) async {
    final client = _httpClient ?? http.Client();

    try {
      final uri = baseUrl.replace(
        path: '/geocode',
        queryParameters: {'q': query},
      );
      final response = await client.get(uri);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GeocodingHttpException(
          statusCode: response.statusCode,
          body: response.body,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>? ?? const [];

      return results
          .map((item) => GeocodeResult.fromJson(item as Map<String, dynamic>))
          .toList();
    } finally {
      if (_httpClient == null) {
        client.close();
      }
    }
  }
}

class GeocodingHttpException implements Exception {
  const GeocodingHttpException({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;

  @override
  String toString() {
    return 'GeocodingHttpException(statusCode: $statusCode, body: $body)';
  }
}
