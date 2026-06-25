import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../routing/models/lat_lng.dart';

abstract interface class GpxExportService {
  Future<File> exportRoute(GpxRouteDocument document);
}

class LocalGpxExportService implements GpxExportService {
  const LocalGpxExportService({
    DirectoryResolver? directoryResolver,
    DateTimeProvider? timestampProvider,
  })  : _directoryResolver = directoryResolver,
        _timestampProvider = timestampProvider;

  final DirectoryResolver? _directoryResolver;
  final DateTimeProvider? _timestampProvider;

  @override
  Future<File> exportRoute(GpxRouteDocument document) async {
    if (document.geometry.length < 2) {
      throw const GpxExportException(
        'Die Route ist zu kurz fuer einen GPX-Export.',
      );
    }

    final baseDirectory =
        await (_directoryResolver?.call() ?? _resolveDefaultDirectory());
    await baseDirectory.create(recursive: true);

    final file = File(
      '${baseDirectory.path}${Platform.pathSeparator}'
      '${_buildFilename()}',
    );
    await file.writeAsString(buildGpx(document));
    return file;
  }

  @visibleForTesting
  String buildGpx(GpxRouteDocument document) {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<gpx version="1.1" creator="LightMapz" '
        'xmlns="http://www.topografix.com/GPX/1/1">',
      )
      ..writeln('  <metadata>')
      ..writeln('    <name>${_xmlEscape(document.name)}</name>')
      ..writeln('  </metadata>');

    for (final waypoint in document.waypoints) {
      buffer
        ..writeln(
          '  <wpt lat="${_formatCoordinate(waypoint.point.lat)}" '
          'lon="${_formatCoordinate(waypoint.point.lng)}">',
        )
        ..writeln('    <name>${_xmlEscape(waypoint.name)}</name>')
        ..writeln('  </wpt>');
    }

    buffer
      ..writeln('  <trk>')
      ..writeln('    <name>${_xmlEscape(document.name)}</name>')
      ..writeln('    <trkseg>');

    for (final point in document.geometry) {
      buffer.writeln(
        '      <trkpt lat="${_formatCoordinate(point.lat)}" '
        'lon="${_formatCoordinate(point.lng)}" />',
      );
    }

    buffer
      ..writeln('    </trkseg>')
      ..writeln('  </trk>')
      ..writeln('</gpx>');

    return buffer.toString();
  }

  Future<Directory> _resolveDefaultDirectory() async {
    final downloadsDirectory = await getDownloadsDirectory();

    if (downloadsDirectory != null) {
      return Directory(
        '${downloadsDirectory.path}${Platform.pathSeparator}LightMapz Exports',
      );
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    return Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}LightMapz Exports',
    );
  }

  String _buildFilename() {
    final timestamp = (_timestampProvider?.call() ?? DateTime.now()).toLocal();
    final normalized = [
      timestamp.year.toString().padLeft(4, '0'),
      timestamp.month.toString().padLeft(2, '0'),
      timestamp.day.toString().padLeft(2, '0'),
      timestamp.hour.toString().padLeft(2, '0'),
      timestamp.minute.toString().padLeft(2, '0'),
      timestamp.second.toString().padLeft(2, '0'),
    ].join('-');

    return 'lightmapz-route-$normalized.gpx';
  }

  String _formatCoordinate(double value) {
    return value.toStringAsFixed(6);
  }

  String _xmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

class GpxRouteDocument {
  const GpxRouteDocument({
    required this.name,
    required this.waypoints,
    required this.geometry,
  });

  final String name;
  final List<GpxWaypoint> waypoints;
  final List<LatLng> geometry;
}

class GpxWaypoint {
  const GpxWaypoint({
    required this.name,
    required this.point,
  });

  final String name;
  final LatLng point;
}

class GpxExportException implements Exception {
  const GpxExportException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}

typedef DirectoryResolver = Future<Directory> Function();
typedef DateTimeProvider = DateTime Function();
