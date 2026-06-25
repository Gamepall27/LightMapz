import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import 'gpx_download_helper.dart';
import '../routing/models/lat_lng.dart';

abstract interface class GpxExportService {
  Future<GpxExportResult> exportRoute(GpxRouteDocument document);
}

abstract interface class GpxImportService {
  Future<GpxRouteDocument> importRouteFromFile(XFile file);
}

class LocalGpxExportService implements GpxExportService, GpxImportService {
  const LocalGpxExportService({
    DirectoryResolver? directoryResolver,
    DateTimeProvider? timestampProvider,
  })  : _directoryResolver = directoryResolver,
        _timestampProvider = timestampProvider;

  final DirectoryResolver? _directoryResolver;
  final DateTimeProvider? _timestampProvider;

  @override
  Future<GpxExportResult> exportRoute(GpxRouteDocument document) async {
    if (document.geometry.length < 2) {
      throw const GpxExportException(
        'Die Route ist zu kurz fuer einen GPX-Export.',
      );
    }

    final content = buildGpx(document);
    final filename = _buildFilename();

    if (kIsWeb) {
      await downloadGpxFile(
        filename: filename,
        content: content,
      );

      return GpxExportResult(filename: filename);
    }

    final baseDirectory =
        await (_directoryResolver?.call() ?? _resolveDefaultDirectory());
    await baseDirectory.create(recursive: true);

    final file = File(
      '${baseDirectory.path}${Platform.pathSeparator}'
      '$filename',
    );
    await file.writeAsString(content);
    return GpxExportResult(
      filename: filename,
      path: file.path,
    );
  }

  @override
  Future<GpxRouteDocument> importRouteFromFile(XFile file) async {
    final content = await file.readAsString();
    final fallbackName = _filenameWithoutExtension(file.name);

    return parseGpx(content, fallbackName: fallbackName);
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

  @visibleForTesting
  GpxRouteDocument parseGpx(String content, {String? fallbackName}) {
    XmlDocument xmlDocument;

    try {
      xmlDocument = XmlDocument.parse(content);
    } on XmlParserException catch (error) {
      throw GpxImportException(
          'Die GPX-Datei konnte nicht gelesen werden: $error');
    }

    final root = xmlDocument.rootElement;

    if (root.name.local.toLowerCase() != 'gpx') {
      throw const GpxImportException('Die Datei ist keine gueltige GPX-Datei.');
    }

    final trackGeometry = _readPoints(root, 'trkpt');
    final routeWaypoints = _readWaypoints(root, 'rtept');
    final genericWaypoints = _readWaypoints(root, 'wpt');
    final geometry = trackGeometry.length >= 2
        ? trackGeometry
        : routeWaypoints.map((waypoint) => waypoint.point).toList();

    final effectiveGeometry = geometry.length >= 2
        ? geometry
        : genericWaypoints.map((waypoint) => waypoint.point).toList();

    if (effectiveGeometry.length < 2) {
      throw const GpxImportException(
        'Die GPX-Datei enthaelt keine importierbare Route.',
      );
    }

    final importedWaypoints = routeWaypoints.length >= 2
        ? routeWaypoints
        : genericWaypoints.length >= 2
            ? genericWaypoints
            : [
                GpxWaypoint(name: 'Start', point: effectiveGeometry.first),
                GpxWaypoint(name: 'Ziel', point: effectiveGeometry.last),
              ];

    return GpxRouteDocument(
      name: _readRouteName(root) ?? fallbackName ?? 'Importierte GPX-Route',
      waypoints: importedWaypoints,
      geometry: effectiveGeometry,
    );
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

  String _filenameWithoutExtension(String filename) {
    final extensionIndex = filename.lastIndexOf('.');

    if (extensionIndex <= 0) {
      return filename;
    }

    return filename.substring(0, extensionIndex);
  }

  String? _readRouteName(XmlElement root) {
    return _firstChildText(_firstDescendant(root, 'metadata'), 'name') ??
        _firstChildText(_firstDescendant(root, 'trk'), 'name') ??
        _firstChildText(_firstDescendant(root, 'rte'), 'name');
  }

  List<LatLng> _readPoints(XmlElement root, String localName) {
    return _descendants(root, localName)
        .map(_parsePoint)
        .whereType<LatLng>()
        .toList(growable: false);
  }

  List<GpxWaypoint> _readWaypoints(XmlElement root, String localName) {
    final elements = _descendants(root, localName).toList(growable: false);

    return [
      for (var index = 0; index < elements.length; index++)
        if (_parsePoint(elements[index]) case final LatLng point)
          GpxWaypoint(
            name: _firstChildText(elements[index], 'name') ??
                'Wegpunkt ${index + 1}',
            point: point,
          ),
    ];
  }

  Iterable<XmlElement> _descendants(XmlElement root, String localName) {
    return root.descendants.whereType<XmlElement>().where(
          (element) => element.name.local.toLowerCase() == localName,
        );
  }

  XmlElement? _firstDescendant(XmlElement root, String localName) {
    for (final element in _descendants(root, localName)) {
      return element;
    }

    return null;
  }

  String? _firstChildText(XmlElement? element, String childLocalName) {
    if (element == null) {
      return null;
    }

    for (final child in element.children.whereType<XmlElement>()) {
      if (child.name.local.toLowerCase() == childLocalName.toLowerCase()) {
        final text = child.innerText.trim();
        return text.isEmpty ? null : text;
      }
    }

    return null;
  }

  LatLng? _parsePoint(XmlElement element) {
    final lat = double.tryParse(element.getAttribute('lat') ?? '');
    final lng = double.tryParse(element.getAttribute('lon') ?? '');

    if (lat == null || lng == null) {
      return null;
    }

    if (!lat.isFinite || !lng.isFinite) {
      return null;
    }

    return LatLng(lat: lat, lng: lng);
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

class GpxExportResult {
  const GpxExportResult({
    required this.filename,
    this.path,
  });

  final String filename;
  final String? path;
}

class GpxExportException implements Exception {
  const GpxExportException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}

class GpxImportException implements Exception {
  const GpxImportException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}

typedef DirectoryResolver = Future<Directory> Function();
typedef DateTimeProvider = DateTime Function();
