import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../../core/components/index.dart";
import "../../../../core/state/service_area_store.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../../core/utils/place_search.dart";

/// What the place picker returns when the passenger taps "Use my current
/// location" (only offered with [PlaceSearchPage.offerCurrentLocation]).
const PlaceSuggestion kCurrentLocationChoice = PlaceSuggestion(
    name: "Current location", secondaryLabel: "", lat: 0, lng: 0);

/// Full-screen search-as-you-type picker for pickup/drop-off. Pops with the
/// selected [PlaceSuggestion], or null if the user backs out without
/// picking anything.
class PlaceSearchPage extends StatefulWidget {
  const PlaceSearchPage({
    super.key,
    required this.title,
    this.offerCurrentLocation = false,
    this.isPickup = false,
  });

  final String title;
  final bool offerCurrentLocation;
  final bool isPickup;

  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounce;
  List<PlaceSuggestion> _results = [];
  bool _isSearching = false;
  int _searchToken = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await searchPlaces(trimmed,
        area: context.read<ServiceAreaStore>().area);
    if (!mounted || token != _searchToken) return;

    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.isPickup ? DesignTokens.lagoon : DesignTokens.primaryBright;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  BackSquareButton(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: DesignTokens.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: DesignTokens.primaryBright, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: DesignTokens.primaryBright.withAlpha(36),
                              spreadRadius: 4),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              size: 20, color: DesignTokens.ink2),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _queryController,
                              autofocus: true,
                              onChanged: _onQueryChanged,
                              cursorColor: DesignTokens.primaryBright,
                              textInputAction: TextInputAction.search,
                              style: TextStyle(
                                  color: DesignTokens.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: false,
                                hintText: widget.title,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                          if (_queryController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _queryController.clear();
                                _onQueryChanged("");
                              },
                              child: Icon(Icons.cancel_rounded,
                                  size: 18, color: DesignTokens.ink2),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(accent)),
          ],
        ),
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              IconTile(
                icon: icon,
                size: 40,
                radius: 12,
                iconSize: 19,
                background: color.withAlpha(DesignTokens.isDark ? 46 : 30),
                foreground: color,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: DesignTokens.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: DesignTokens.ink2,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Color accent) {
    final currentLocation = widget.offerCurrentLocation
        ? _row(
            icon: Icons.my_location_rounded,
            color: DesignTokens.lagoon,
            title: "Use my current location",
            subtitle: "Current GPS location",
            onTap: () => Navigator.pop(context, kCurrentLocationChoice),
          )
        : null;

    if (_isSearching && _results.isEmpty) {
      return Column(
        children: [
          if (currentLocation != null) currentLocation,
          const Expanded(
              child:
                  Center(child: CircularProgressIndicator(strokeWidth: 2.4))),
        ],
      );
    }

    if (_queryController.text.trim().isEmpty) {
      return ListView(
        children: [
          if (currentLocation != null) currentLocation,
          const EmptyState(
            icon: Icons.travel_explore_rounded,
            message: "Start typing to search for a place in Guiuan.",
          ),
        ],
      );
    }

    if (_results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        children: [
          IconTile(
            icon: Icons.travel_explore_rounded,
            size: 56,
            radius: 18,
            iconSize: 26,
            background: DesignTokens.surface2,
            foreground: DesignTokens.ink2,
          ),
          const SizedBox(height: 12),
          Text(
            "No places in Guiuan match “${_queryController.text.trim()}”.",
            textAlign: TextAlign.center,
            style: DesignTokens.headline,
          ),
          const SizedBox(height: 6),
          Text(
            "FindMeTricycle only operates within Guiuan. Try another name, or go back and tap the spot on the map.",
            textAlign: TextAlign.center,
            style: DesignTokens.body,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: _results.length + (currentLocation == null ? 0 : 1),
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 74,
        endIndent: 20,
        color: DesignTokens.line,
      ),
      itemBuilder: (context, index) {
        if (currentLocation != null) {
          if (index == 0) return currentLocation;
          index -= 1;
        }
        final place = _results[index];
        return _row(
          icon: place.isArea ? Icons.map_outlined : Icons.place_outlined,
          color: accent,
          title: place.name,
          subtitle: place.secondaryLabel,
          onTap: () => Navigator.pop(context, place),
        );
      },
    );
  }
}
