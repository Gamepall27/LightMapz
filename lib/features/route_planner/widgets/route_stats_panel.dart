import 'package:flutter/material.dart';

import '../../../routing/models/route_result.dart';

class RouteStatsPanel extends StatelessWidget {
  const RouteStatsPanel({
    required this.route,
    super.key,
  });

  final RouteResult? route;

  @override
  Widget build(BuildContext context) {
    if (route == null) {
      return const SizedBox.shrink();
    }

    final currentRoute = route!;

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
            Text(
              'Routendaten',
              style: Theme.of(context).textTheme.titleMedium,
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
                  value: _formatDuration(currentRoute.durationSeconds),
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
