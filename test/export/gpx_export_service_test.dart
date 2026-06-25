import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lightmapz/export/gpx_export_service.dart';
import 'package:lightmapz/routing/models/lat_lng.dart';

void main() {
  group('LocalGpxExportService', () {
    test('writes a GPX file with metadata, waypoints, and track geometry',
        () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'lightmapz_gpx_test_',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));

      final service = LocalGpxExportService(
        directoryResolver: () async => tempDirectory,
        timestampProvider: () => DateTime(2026, 6, 25, 14, 30, 45),
      );

      final file = await service.exportRoute(
        const GpxRouteDocument(
          name: 'Start < Ziel & Test',
          waypoints: [
            GpxWaypoint(
              name: 'Start',
              point: LatLng(lat: 51.2277, lng: 6.7735),
            ),
            GpxWaypoint(
              name: 'Ziel',
              point: LatLng(lat: 51.4508, lng: 7.0131),
            ),
          ],
          geometry: [
            LatLng(lat: 51.2277, lng: 6.7735),
            LatLng(lat: 51.3000, lng: 6.9000),
            LatLng(lat: 51.4508, lng: 7.0131),
          ],
        ),
      );

      expect(file.existsSync(), isTrue);
      expect(file.path, endsWith('lightmapz-route-2026-06-25-14-30-45.gpx'));

      final content = await file.readAsString();
      expect(content, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(
        content,
        contains('<name>Start &lt; Ziel &amp; Test</name>'),
      );
      expect(
        content,
        contains('<wpt lat="51.227700" lon="6.773500">'),
      );
      expect(
        content,
        contains('<trkpt lat="51.300000" lon="6.900000" />'),
      );
      expect(content, contains('</gpx>'));
    });

    test('rejects routes with fewer than two geometry points', () async {
      final service = LocalGpxExportService(
        directoryResolver: () async => Directory.systemTemp,
      );

      expect(
        () => service.exportRoute(
          const GpxRouteDocument(
            name: 'Zu kurz',
            waypoints: [],
            geometry: [LatLng(lat: 51.2277, lng: 6.7735)],
          ),
        ),
        throwsA(isA<GpxExportException>()),
      );
    });
  });
}
