import 'package:flutter/material.dart';

class RoadAvoidanceSlider extends StatelessWidget {
  const RoadAvoidanceSlider({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Straßen vermeiden',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text('$value %'),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 100,
          divisions: 4,
          label: _labelForValue(value),
          onChanged: (newValue) => onChanged(newValue.round()),
        ),
        Text(
          _labelForValue(value),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _labelForValue(int value) {
    if (value <= 0) {
      return 'Schnellere/normalere Route';
    }
    if (value <= 25) {
      return 'Ruhige Straßen bevorzugen';
    }
    if (value <= 50) {
      return 'Radwege und Nebenstraßen stark bevorzugen';
    }
    if (value <= 75) {
      return 'Hauptstraßen massiv vermeiden';
    }
    return 'Straßen maximal vermeiden, auch bei großem Umweg';
  }
}

class GreenwayDetourRadiusSlider extends StatelessWidget {
  const GreenwayDetourRadiusSlider({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Gewünschte Umweggröße',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text('$value km'),
          ],
        ),
        Slider(
          key: const Key('greenway_detour_radius_slider'),
          value: value.toDouble(),
          min: 5,
          max: 12,
          divisions: 7,
          label: '$value km',
          onChanged: (newValue) => onChanged(newValue.round()),
        ),
        Text(
          'Legt fest, wie weit die Route vom direkten Korridor abweichen soll. Größere Werte bevorzugen weiter außen liegende Feld-/Waldwege.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class MinimumFieldWayShareSlider extends StatelessWidget {
  const MinimumFieldWayShareSlider({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mindestanteil Feld-/Waldwege',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text('$value %'),
          ],
        ),
        Slider(
          key: const Key('minimum_field_way_share_slider'),
          value: value.toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          label: '$value %',
          onChanged: (newValue) => onChanged(newValue.round()),
        ),
        Text(
          'Falls der Wert nicht erreichbar ist, wird die feldwegreichste mögliche Route gewählt.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
