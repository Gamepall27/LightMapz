import 'dart:async';

import 'package:flutter/material.dart';

import '../../../geocoding/geocoding_service.dart';
import '../../../geocoding/models/geocode_result.dart';

class AddressInputPanel extends StatefulWidget {
  const AddressInputPanel({
    required this.startAddress,
    required this.destinationAddress,
    required this.geocodingService,
    required this.onStartAddressChanged,
    required this.onDestinationAddressChanged,
    super.key,
  });

  final String startAddress;
  final String destinationAddress;
  final GeocodingService geocodingService;
  final ValueChanged<String> onStartAddressChanged;
  final ValueChanged<String> onDestinationAddressChanged;

  @override
  State<AddressInputPanel> createState() => _AddressInputPanelState();
}

class _AddressInputPanelState extends State<AddressInputPanel> {
  static const _minimumQueryLength = 3;
  static const _suggestionDebounce = Duration(milliseconds: 300);

  late final TextEditingController startController;
  late final TextEditingController destinationController;
  late final FocusNode startFocusNode;
  late final FocusNode destinationFocusNode;
  Timer? startDebounce;
  Timer? destinationDebounce;
  List<GeocodeResult> startSuggestions = const [];
  List<GeocodeResult> destinationSuggestions = const [];
  bool isLoadingStartSuggestions = false;
  bool isLoadingDestinationSuggestions = false;
  bool showStartSuggestions = false;
  bool showDestinationSuggestions = false;
  String? startSuggestionError;
  String? destinationSuggestionError;
  int startSearchRequestId = 0;
  int destinationSearchRequestId = 0;

  @override
  void initState() {
    super.initState();
    startController = TextEditingController(text: widget.startAddress);
    destinationController = TextEditingController(
      text: widget.destinationAddress,
    );
    startFocusNode = FocusNode()
      ..addListener(() {
        if (!startFocusNode.hasFocus) {
          _clearStartSuggestions();
        }
      });
    destinationFocusNode = FocusNode()
      ..addListener(() {
        if (!destinationFocusNode.hasFocus) {
          _clearDestinationSuggestions();
        }
      });
  }

  @override
  void dispose() {
    startDebounce?.cancel();
    destinationDebounce?.cancel();
    startController.dispose();
    destinationController.dispose();
    startFocusNode.dispose();
    destinationFocusNode.dispose();
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
          focusNode: startFocusNode,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Startadresse',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) {
            widget.onStartAddressChanged(value);
            _scheduleStartSuggestions(value);
          },
        ),
        _AddressSuggestions(
          fieldKey: 'start',
          suggestions: startSuggestions,
          isLoading: isLoadingStartSuggestions,
          errorMessage: startSuggestionError,
          hasFocus: startFocusNode.hasFocus,
          isVisible: showStartSuggestions,
          query: startController.text,
          onSelected: _selectStartSuggestion,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('destination_address_field'),
          controller: destinationController,
          focusNode: destinationFocusNode,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Zieladresse',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) {
            widget.onDestinationAddressChanged(value);
            _scheduleDestinationSuggestions(value);
          },
        ),
        _AddressSuggestions(
          fieldKey: 'destination',
          suggestions: destinationSuggestions,
          isLoading: isLoadingDestinationSuggestions,
          errorMessage: destinationSuggestionError,
          hasFocus: destinationFocusNode.hasFocus,
          isVisible: showDestinationSuggestions,
          query: destinationController.text,
          onSelected: _selectDestinationSuggestion,
        ),
      ],
    );
  }

  void _scheduleStartSuggestions(String query) {
    startDebounce?.cancel();
    final requestId = ++startSearchRequestId;

    if (query.trim().length < _minimumQueryLength) {
      setState(() {
        startSuggestions = const [];
        startSuggestionError = null;
        isLoadingStartSuggestions = false;
        showStartSuggestions = false;
      });
      return;
    }

    setState(() {
      isLoadingStartSuggestions = true;
      startSuggestionError = null;
      showStartSuggestions = true;
    });

    startDebounce = Timer(_suggestionDebounce, () {
      _loadStartSuggestions(query, requestId);
    });
  }

  void _scheduleDestinationSuggestions(String query) {
    destinationDebounce?.cancel();
    final requestId = ++destinationSearchRequestId;

    if (query.trim().length < _minimumQueryLength) {
      setState(() {
        destinationSuggestions = const [];
        destinationSuggestionError = null;
        isLoadingDestinationSuggestions = false;
        showDestinationSuggestions = false;
      });
      return;
    }

    setState(() {
      isLoadingDestinationSuggestions = true;
      destinationSuggestionError = null;
      showDestinationSuggestions = true;
    });

    destinationDebounce = Timer(_suggestionDebounce, () {
      _loadDestinationSuggestions(query, requestId);
    });
  }

  Future<void> _loadStartSuggestions(String query, int requestId) async {
    try {
      final results = await widget.geocodingService.search(query.trim());

      if (!mounted || requestId != startSearchRequestId) {
        return;
      }

      setState(() {
        startSuggestions = results.take(5).toList();
        isLoadingStartSuggestions = false;
        startSuggestionError = null;
      });
    } on Exception {
      if (!mounted || requestId != startSearchRequestId) {
        return;
      }

      setState(() {
        startSuggestions = const [];
        isLoadingStartSuggestions = false;
        startSuggestionError = 'Vorschlaege konnten nicht geladen werden.';
      });
    }
  }

  Future<void> _loadDestinationSuggestions(String query, int requestId) async {
    try {
      final results = await widget.geocodingService.search(query.trim());

      if (!mounted || requestId != destinationSearchRequestId) {
        return;
      }

      setState(() {
        destinationSuggestions = results.take(5).toList();
        isLoadingDestinationSuggestions = false;
        destinationSuggestionError = null;
      });
    } on Exception {
      if (!mounted || requestId != destinationSearchRequestId) {
        return;
      }

      setState(() {
        destinationSuggestions = const [];
        isLoadingDestinationSuggestions = false;
        destinationSuggestionError =
            'Vorschlaege konnten nicht geladen werden.';
      });
    }
  }

  void _selectStartSuggestion(GeocodeResult suggestion) {
    startDebounce?.cancel();
    startSearchRequestId++;
    _setControllerText(startController, suggestion.label);
    widget.onStartAddressChanged(suggestion.label);
    setState(() {
      startSuggestions = const [];
      isLoadingStartSuggestions = false;
      startSuggestionError = null;
      showStartSuggestions = false;
    });
  }

  void _selectDestinationSuggestion(GeocodeResult suggestion) {
    destinationDebounce?.cancel();
    destinationSearchRequestId++;
    _setControllerText(destinationController, suggestion.label);
    widget.onDestinationAddressChanged(suggestion.label);
    setState(() {
      destinationSuggestions = const [];
      isLoadingDestinationSuggestions = false;
      destinationSuggestionError = null;
      showDestinationSuggestions = false;
    });
  }

  void _clearStartSuggestions() {
    if (startSuggestions.isEmpty &&
        !isLoadingStartSuggestions &&
        startSuggestionError == null &&
        !showStartSuggestions) {
      return;
    }

    setState(() {
      startSuggestions = const [];
      isLoadingStartSuggestions = false;
      startSuggestionError = null;
      showStartSuggestions = false;
    });
  }

  void _clearDestinationSuggestions() {
    if (destinationSuggestions.isEmpty &&
        !isLoadingDestinationSuggestions &&
        destinationSuggestionError == null &&
        !showDestinationSuggestions) {
      return;
    }

    setState(() {
      destinationSuggestions = const [];
      isLoadingDestinationSuggestions = false;
      destinationSuggestionError = null;
      showDestinationSuggestions = false;
    });
  }

  void _setControllerText(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class _AddressSuggestions extends StatelessWidget {
  const _AddressSuggestions({
    required this.fieldKey,
    required this.suggestions,
    required this.isLoading,
    required this.errorMessage,
    required this.hasFocus,
    required this.isVisible,
    required this.query,
    required this.onSelected,
  });

  final String fieldKey;
  final List<GeocodeResult> suggestions;
  final bool isLoading;
  final String? errorMessage;
  final bool hasFocus;
  final bool isVisible;
  final String query;
  final ValueChanged<GeocodeResult> onSelected;

  @override
  Widget build(BuildContext context) {
    if (!isVisible ||
        !hasFocus ||
        query.trim().length < _AddressInputPanelState._minimumQueryLength) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final children = <Widget>[];

    if (isLoading) {
      children.add(
        const _SuggestionStatusRow(
          key: Key('address_suggestions_loading'),
          label: 'Suche Adressen...',
          isLoading: true,
        ),
      );
    } else if (errorMessage != null) {
      children.add(
        _SuggestionStatusRow(
          key: const Key('address_suggestions_error'),
          label: errorMessage!,
        ),
      );
    } else if (suggestions.isEmpty) {
      children.add(
        const _SuggestionStatusRow(
          key: Key('address_suggestions_empty'),
          label: 'Keine Vorschlaege gefunden',
        ),
      );
    } else {
      for (final suggestion in suggestions) {
        children.add(
          InkWell(
            key: Key('${fieldKey}_address_suggestion_${suggestion.label}'),
            onTap: () => onSelected(suggestion),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        key: Key('${fieldKey}_address_suggestions'),
        color: colorScheme.surface,
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionStatusRow extends StatelessWidget {
  const _SuggestionStatusRow({
    required this.label,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          if (isLoading) ...[
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
