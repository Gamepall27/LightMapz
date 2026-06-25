import 'package:flutter/material.dart';

import '../route_planner_controller.dart';

class NavigationStatusPanel extends StatelessWidget {
  const NavigationStatusPanel({
    required this.stats,
    required this.isNavigationActive,
    super.key,
  });

  final NavigationStats stats;
  final bool isNavigationActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      key: const Key('navigation_status_panel'),
      color: colorScheme.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavigationMetric(
                  label: 'Ankunft',
                  value: _formatArrivalTime(stats.estimatedArrivalTime),
                ),
                const SizedBox(width: 14),
                _NavigationMetric(
                  label: 'Dauer',
                  value: _formatDuration(stats.remainingDurationSeconds),
                ),
                const SizedBox(width: 14),
                _NavigationMetric(
                  label: 'Distanz',
                  value: _formatDistance(stats.remainingDistanceMeters),
                ),
                if (isNavigationActive) ...[
                  const SizedBox(width: 10),
                  Icon(
                    Icons.navigation,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                ],
              ],
            ),
            if (stats.nextInstruction != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.turn_right,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${_formatDistance(stats.nextInstruction!.distanceMeters)}: '
                      '${stats.nextInstruction!.text}',
                      key: const Key('navigation_instruction_text'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatArrivalTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).round();

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return '$hours h';
    }

    return '$hours h $remainingMinutes min';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

class _NavigationMetric extends StatelessWidget {
  const _NavigationMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
