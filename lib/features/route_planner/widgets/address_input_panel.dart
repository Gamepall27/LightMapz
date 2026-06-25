import 'dart:async';

import 'package:flutter/material.dart';

import '../../../geocoding/geocoding_service.dart';
import '../../../geocoding/models/geocode_result.dart';
import '../route_planner_controller.dart';

typedef WaypointAddressChanged = void Function(String waypointId, String value);
typedef EmptySuggestionSelected = Future<bool> Function();

class AddressInputPanel extends StatelessWidget {
  const AddressInputPanel({
    required this.startAddress,
    required this.destinationAddress,
    required this.waypoints,
    required this.geocodingService,
    required this.onStartAddressChanged,
    required this.onDestinationAddressChanged,
    required this.onAddWaypoint,
    required this.onWaypointAddressChanged,
    required this.onMoveWaypointUp,
    required this.onMoveWaypointDown,
    required this.onRemoveWaypoint,
    required this.onUseCurrentLocationAsStart,
    required this.onUseCurrentLocationAsDestination,
    super.key,
  });

  final String startAddress;
  final String destinationAddress;
  final List<RouteWaypoint> waypoints;
  final GeocodingService geocodingService;
  final ValueChanged<String> onStartAddressChanged;
  final ValueChanged<String> onDestinationAddressChanged;
  final VoidCallback onAddWaypoint;
  final WaypointAddressChanged onWaypointAddressChanged;
  final ValueChanged<String> onMoveWaypointUp;
  final ValueChanged<String> onMoveWaypointDown;
  final ValueChanged<String> onRemoveWaypoint;
  final EmptySuggestionSelected onUseCurrentLocationAsStart;
  final EmptySuggestionSelected onUseCurrentLocationAsDestination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Adressen',
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              key: const Key('add_waypoint_button'),
              onPressed: onAddWaypoint,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Zwischenstopp'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AddressAutocompleteField(
          key: const ValueKey('start_address_autocomplete'),
          fieldKey: 'start',
          initialValue: startAddress,
          labelText: 'Startadresse',
          textInputAction: TextInputAction.next,
          geocodingService: geocodingService,
          onChanged: onStartAddressChanged,
          emptySuggestionLabel: 'Eigener Standort',
          onEmptySuggestionSelected: onUseCurrentLocationAsStart,
        ),
        for (var index = 0; index < waypoints.length; index++) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AddressAutocompleteField(
                  key: ValueKey('waypoint_${waypoints[index].id}'),
                  fieldKey: 'waypoint_${waypoints[index].id}',
                  initialValue: waypoints[index].address,
                  labelText: 'Zwischenstopp ${index + 1}',
                  textInputAction: TextInputAction.next,
                  geocodingService: geocodingService,
                  onChanged: (value) {
                    onWaypointAddressChanged(waypoints[index].id, value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      key: Key('move_waypoint_up_${waypoints[index].id}'),
                      tooltip: 'Zwischenstopp nach oben',
                      onPressed: index == 0
                          ? null
                          : () => onMoveWaypointUp(waypoints[index].id),
                      icon: const Icon(Icons.keyboard_arrow_up),
                    ),
                    const SizedBox(height: 4),
                    IconButton.filledTonal(
                      key: Key('move_waypoint_down_${waypoints[index].id}'),
                      tooltip: 'Zwischenstopp nach unten',
                      onPressed: index == waypoints.length - 1
                          ? null
                          : () => onMoveWaypointDown(waypoints[index].id),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: Key('remove_waypoint_${waypoints[index].id}'),
                tooltip: 'Zwischenstopp entfernen',
                onPressed: () => onRemoveWaypoint(waypoints[index].id),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        AddressAutocompleteField(
          key: const ValueKey('destination_address_autocomplete'),
          fieldKey: 'destination',
          initialValue: destinationAddress,
          labelText: 'Zieladresse',
          textInputAction: TextInputAction.done,
          geocodingService: geocodingService,
          onChanged: onDestinationAddressChanged,
          emptySuggestionLabel: 'Eigener Standort',
          onEmptySuggestionSelected: onUseCurrentLocationAsDestination,
        ),
      ],
    );
  }
}

class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    required this.fieldKey,
    required this.initialValue,
    required this.labelText,
    required this.textInputAction,
    required this.geocodingService,
    required this.onChanged,
    this.emptySuggestionLabel,
    this.onEmptySuggestionSelected,
    super.key,
  });

  final String fieldKey;
  final String initialValue;
  final String labelText;
  final TextInputAction textInputAction;
  final GeocodingService geocodingService;
  final ValueChanged<String> onChanged;
  final String? emptySuggestionLabel;
  final EmptySuggestionSelected? onEmptySuggestionSelected;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  static const _minimumQueryLength = 3;
  static const _suggestionDebounce = Duration(milliseconds: 300);

  late final TextEditingController controller;
  late final FocusNode focusNode;
  Timer? debounce;
  List<GeocodeResult> suggestions = const [];
  bool isLoadingSuggestions = false;
  bool showSuggestions = false;
  String? suggestionError;
  int searchRequestId = 0;
  bool isSelectingEmptySuggestion = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue);
    focusNode = FocusNode()
      ..addListener(() {
        if (!focusNode.hasFocus) {
          _clearSuggestions();
        } else if (controller.text.trim().isEmpty &&
            widget.onEmptySuggestionSelected != null) {
          setState(() {
            showSuggestions = true;
          });
        }
      });
  }

  @override
  void didUpdateWidget(covariant AddressAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!focusNode.hasFocus && controller.text != widget.initialValue) {
      _setControllerText(widget.initialValue);
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          key: Key('${widget.fieldKey}_address_field'),
          controller: controller,
          focusNode: focusNode,
          textInputAction: widget.textInputAction,
          decoration: InputDecoration(
            labelText: widget.labelText,
            border: const OutlineInputBorder(),
            isDense: true,
            errorText: suggestionError,
            suffixIcon: widget.onEmptySuggestionSelected == null
                ? null
                : IconButton(
                    key: Key('${widget.fieldKey}_current_location_button'),
                    tooltip: 'Aktuellen Standort verwenden',
                    onPressed: _selectEmptySuggestion,
                    icon: const Icon(Icons.my_location),
                  ),
          ),
          onTap: () {
            if (controller.text.trim().isEmpty &&
                widget.onEmptySuggestionSelected != null) {
              setState(() {
                showSuggestions = true;
              });
            }
          },
          onChanged: (value) {
            widget.onChanged(value);
            _scheduleSuggestions(value);
          },
        ),
        _AddressSuggestions(
          fieldKey: widget.fieldKey,
          suggestions: suggestions,
          isLoading: isLoadingSuggestions,
          errorMessage: suggestionError,
          hasFocus: focusNode.hasFocus,
          isVisible: showSuggestions,
          query: controller.text,
          emptySuggestionLabel: widget.emptySuggestionLabel,
          onEmptySuggestionSelected: _selectEmptySuggestion,
          onSelected: _selectSuggestion,
        ),
      ],
    );
  }

  void _scheduleSuggestions(String query) {
    debounce?.cancel();
    final requestId = ++searchRequestId;

    if (query.trim().length < _minimumQueryLength) {
      setState(() {
        suggestions = const [];
        suggestionError = null;
        isLoadingSuggestions = false;
        showSuggestions = false;
      });
      return;
    }

    setState(() {
      isLoadingSuggestions = true;
      suggestionError = null;
      showSuggestions = true;
    });

    debounce = Timer(_suggestionDebounce, () {
      _loadSuggestions(query, requestId);
    });
  }

  Future<void> _loadSuggestions(String query, int requestId) async {
    try {
      final results = await widget.geocodingService.search(query.trim());

      if (!mounted || requestId != searchRequestId) {
        return;
      }

      setState(() {
        suggestions = results.take(5).toList();
        isLoadingSuggestions = false;
        suggestionError = null;
      });
    } on Exception {
      if (!mounted || requestId != searchRequestId) {
        return;
      }

      setState(() {
        suggestions = const [];
        isLoadingSuggestions = false;
        suggestionError = 'Vorschlaege konnten nicht geladen werden.';
      });
    }
  }

  void _selectSuggestion(GeocodeResult suggestion) {
    debounce?.cancel();
    searchRequestId++;
    _setControllerText(suggestion.label);
    widget.onChanged(suggestion.label);
    setState(() {
      suggestions = const [];
      isLoadingSuggestions = false;
      suggestionError = null;
      showSuggestions = false;
    });
  }

  Future<void> _selectEmptySuggestion() async {
    final label = widget.emptySuggestionLabel;

    if (label == null ||
        widget.onEmptySuggestionSelected == null ||
        isSelectingEmptySuggestion) {
      return;
    }

    debounce?.cancel();
    searchRequestId++;
    setState(() {
      suggestions = const [];
      isLoadingSuggestions = true;
      suggestionError = null;
      showSuggestions = true;
      isSelectingEmptySuggestion = true;
    });

    final didSelect = await widget.onEmptySuggestionSelected!();

    if (!mounted) {
      return;
    }

    if (didSelect) {
      _setControllerText(label);
      focusNode.unfocus();
    }

    setState(() {
      suggestions = const [];
      isLoadingSuggestions = false;
      suggestionError =
          didSelect ? null : 'Standort konnte nicht ermittelt werden.';
      showSuggestions = false;
      isSelectingEmptySuggestion = false;
    });
  }

  void _clearSuggestions() {
    if (suggestions.isEmpty &&
        !isLoadingSuggestions &&
        suggestionError == null &&
        !showSuggestions) {
      return;
    }

    setState(() {
      suggestions = const [];
      isLoadingSuggestions = false;
      suggestionError = null;
      showSuggestions = false;
    });
  }

  void _setControllerText(String value) {
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
    required this.emptySuggestionLabel,
    required this.onEmptySuggestionSelected,
    required this.onSelected,
  });

  final String fieldKey;
  final List<GeocodeResult> suggestions;
  final bool isLoading;
  final String? errorMessage;
  final bool hasFocus;
  final bool isVisible;
  final String query;
  final String? emptySuggestionLabel;
  final Future<void> Function()? onEmptySuggestionSelected;
  final ValueChanged<GeocodeResult> onSelected;

  @override
  Widget build(BuildContext context) {
    if (!isVisible || !hasFocus) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final children = <Widget>[];
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty &&
        emptySuggestionLabel != null &&
        onEmptySuggestionSelected != null) {
      children.add(
        InkWell(
          key: Key('${fieldKey}_current_location_suggestion'),
          onTap: () {
            onEmptySuggestionSelected?.call();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.my_location,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    emptySuggestionLabel!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (trimmedQuery.length <
        _AddressAutocompleteFieldState._minimumQueryLength) {
      return const SizedBox.shrink();
    } else if (isLoading) {
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
