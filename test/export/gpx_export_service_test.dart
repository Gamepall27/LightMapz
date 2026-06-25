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

      final exportResult = await service.exportRoute(
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

      expect(exportResult.path, isNotNull);
      expect(
        exportResult.filename,
        'lightmapz-route-2026-06-25-14-30-45.gpx',
      );
      expect(exportResult.path, endsWith(exportResult.filename));

      final file = File(exportResult.path!);
      expect(file.existsSync(), isTrue);

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

    test('parses GPX tracks and route waypoints for import', () {
      const gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Test">
  <metadata>
    <name>Import Test</name>
  </metadata>
  <rte>
    <name>Plan A</name>
    <rtept lat="51.1000" lon="7.1000"><name>Startpunkt</name></rtept>
    <rtept lat="51.2000" lon="7.2000"><name>Zwischenziel</name></rtept>
    <rtept lat="51.3000" lon="7.3000"><name>Zielpunkt</name></rtept>
  </rte>
  <trk>
    <name>Track A</name>
    <trkseg>
      <trkpt lat="51.1000" lon="7.1000" />
      <trkpt lat="51.1500" lon="7.1500" />
      <trkpt lat="51.3000" lon="7.3000" />
    </trkseg>
  </trk>
</gpx>
''';
      final service = LocalGpxExportService();

      final document = service.parseGpx(
        gpxContent,
        fallbackName: 'fallback',
      );

      expect(document.name, 'Import Test');
      expect(document.geometry, const [
        LatLng(lat: 51.1, lng: 7.1),
        LatLng(lat: 51.15, lng: 7.15),
        LatLng(lat: 51.3, lng: 7.3),
      ]);
      expect(
        document.waypoints.map((waypoint) => waypoint.name).toList(),
        ['Startpunkt', 'Zwischenziel', 'Zielpunkt'],
      );
    });

    test('rejects GPX files without a usable route', () {
      const gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Test">
  <wpt lat="51.1000" lon="7.1000"><name>Nur ein Punkt</name></wpt>
</gpx>
''';
      final service = LocalGpxExportService();

      expect(
        () => service.parseGpx(gpxContent),
        throwsA(isA<GpxImportException>()),
      );
    });
  });
}
