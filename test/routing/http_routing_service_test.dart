import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/routing/http_routing_service.dart';
import 'package:lightmapz/routing/models/lat_lng.dart';
import 'package:lightmapz/routing/models/route_request.dart';

void main() {
  group('HttpRoutingService', () {
    late HttpServer server;
    late List<Map<String, dynamic>> receivedBodies;
    var statusCode = 200;

    setUp(() async {
      receivedBodies = [];
      statusCode = 200;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        if (body.isNotEmpty) {
          receivedBodies.add(jsonDecode(body) as Map<String, dynamic>);
        }

        request.response.statusCode = statusCode;
        request.response.headers.contentType = ContentType.json;

        if (statusCode >= 200 && statusCode < 300) {
          request.response.write(jsonEncode({
            'geometry': [
              {'lat': 51.2277, 'lng': 6.7735},
              {'lat': 51.4508, 'lng': 7.0131},
            ],
            'distanceMeters': 42100,
            'durationSeconds': 10800,
            'roadSharePercent': 8.5,
            'cyclewaySharePercent': 71.2,
            'pathSharePercent': 20.3,
            'warnings': [
              'Eine komplett straßenfreie Route wurde nicht gefunden.',
            ],
            'segments': [
              {
                'distanceMeters': 1200,
                'surface': 'asphalt',
                'wayType': 'cycleway',
                'roadClass': 'cycleway',
              },
            ],
          }));
        } else {
          request.response.write(jsonEncode({'error': 'backend failed'}));
        }

        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('posts the route request and parses the route response', () async {
      final service = HttpRoutingService(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      );

      final result = await service.calculateRoute(
        const RouteRequest(
          start: LatLng(lat: 51.2277, lng: 6.7735),
          destination: LatLng(lat: 51.4508, lng: 7.0131),
          roadAvoidanceStrictness: 75,
        ),
      );

      expect(receivedBodies.single, {
        'start': {
          'lat': 51.2277,
          'lng': 6.7735,
        },
        'destination': {
          'lat': 51.4508,
          'lng': 7.0131,
        },
        'profile': 'bike',
        'roadAvoidanceStrictness': 75,
        'preferForestWays': false,
      });
      expect(result.distanceMeters, 42100);
      expect(result.geometry, hasLength(2));
      expect(result.segments.single.roadClass, 'cycleway');
    });

    test('throws a typed exception when the backend returns an error',
        () async {
      statusCode = 500;
      final service = HttpRoutingService(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      );

      expect(
        service.calculateRoute(
          const RouteRequest(
            start: LatLng(lat: 51.2277, lng: 6.7735),
            destination: LatLng(lat: 51.4508, lng: 7.0131),
            roadAvoidanceStrictness: 75,
          ),
        ),
        throwsA(isA<RoutingHttpException>()),
      );
    });
  });
}
