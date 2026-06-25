import 'package:flutter/material.dart';

class AddressInputPanel extends StatefulWidget {
  const AddressInputPanel({
    required this.startAddress,
    required this.destinationAddress,
    required this.onStartAddressChanged,
    required this.onDestinationAddressChanged,
    super.key,
  });

  final String startAddress;
  final String destinationAddress;
  final ValueChanged<String> onStartAddressChanged;
  final ValueChanged<String> onDestinationAddressChanged;

  @override
  State<AddressInputPanel> createState() => _AddressInputPanelState();
}

class _AddressInputPanelState extends State<AddressInputPanel> {
  late final TextEditingController startController;
  late final TextEditingController destinationController;

  @override
  void initState() {
    super.initState();
    startController = TextEditingController(text: widget.startAddress);
    destinationController = TextEditingController(
      text: widget.destinationAddress,
    );
  }

  @override
  void dispose() {
    startController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adressen',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('start_address_field'),
          controller: startController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Startadresse',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: widget.onStartAddressChanged,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('destination_address_field'),
          controller: destinationController,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Zieladresse',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: widget.onDestinationAddressChanged,
        ),
      ],
    );
  }
}
