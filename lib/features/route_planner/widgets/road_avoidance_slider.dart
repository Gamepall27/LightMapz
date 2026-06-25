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
