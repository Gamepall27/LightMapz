import 'package:flutter/material.dart';

import '../../../routing/models/route_result.dart';

class RouteStatsPanel extends StatelessWidget {
  const RouteStatsPanel({
    required this.route,
    required this.averageSpeedKmh,
    this.onExportGpx,
    this.isExporting = false,
    super.key,
  });

  final RouteResult? route;
  final double averageSpeedKmh;
  final Future<void> Function()? onExportGpx;
  final bool isExporting;

  @override
  Widget build(BuildContext context) {
    if (route == null) {
      return const SizedBox.shrink();
    }

    final currentRoute = route!;
    final calculatedDurationSeconds = _calculateDurationSeconds(
      distanceMeters: currentRoute.distanceMeters,
      averageSpeedKmh: averageSpeedKmh,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Routendaten',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onExportGpx != null)
                  OutlinedButton.icon(
                    key: const Key('export_gpx_button'),
                    onPressed: isExporting ? null : onExportGpx,
                    icon: isExporting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: const Text('GPX'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                _StatItem(
                  label: 'Distanz',
                  value: _formatDistance(currentRoute.distanceMeters),
                ),
                _StatItem(
                  label: 'Dauer',
                  value: _formatDuration(calculatedDurationSeconds),
                ),
                _StatItem(
                  label: 'Tempo',
                  value: '${_formatSpeed(averageSpeedKmh)} km/h',
                ),
                _StatItem(
                  label: 'Straßenanteil',
                  value: _formatPercent(currentRoute.roadSharePercent),
                ),
                _StatItem(
                  label: 'Radweganteil',
                  value: _formatPercent(currentRoute.cyclewaySharePercent),
                ),
                _StatItem(
                  label: 'Weganteil',
                  value: _formatPercent(currentRoute.pathSharePercent),
                ),
              ],
            ),
            for (final warning in currentRoute.warnings) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(warning)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours == 0) {
      return '$minutes min';
    }

    return '$hours h $minutes min';
  }

  int _calculateDurationSeconds({
    required double distanceMeters,
    required double averageSpeedKmh,
  }) {
    final metersPerSecond = averageSpeedKmh.clamp(1, 100) / 3.6;
    return (distanceMeters / metersPerSecond).round();
  }

  String _formatSpeed(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }

    return value.toStringAsFixed(1);
  }

  String _formatPercent(double value) {
    return '${value.toStringAsFixed(1)} %';
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
