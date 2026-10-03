import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../../core/state/service_area_store.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../../core/utils/place_search.dart";

/// Full-screen search-as-you-type picker for pickup/drop-off. Pops with the
/// selected [PlaceSuggestion], or null if the user backs out without
/// picking anything.
class PlaceSearchPage extends StatefulWidget {
  const PlaceSearchPage({super.key, required this.title});

  final String title;

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
    return Scaffold(
      backgroundColor: DesignTokens.bg,
      appBar: AppBar(
        backgroundColor: DesignTokens.bg,
        foregroundColor: DesignTokens.text,
        elevation: 0,
        titleSpacing: 0,
        title: TextField(
          controller: _queryController,
          autofocus: true,
          onChanged: _onQueryChanged,
          style: TextStyle(
            color: DesignTokens.text,
            fontFamily: DesignTokens.fontDmSans,
          ),
          decoration: InputDecoration(
            hintText: widget.title,
            hintStyle: TextStyle(color: DesignTokens.muted),
            border: InputBorder.none,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching && _results.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: DesignTokens.accent),
      );
    }

    if (_queryController.text.trim().isEmpty) {
      return Center(
        child: Text(
          "Start typing to search for a place.",
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: DesignTokens.muted),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.travel_explore_rounded,
                  color: DesignTokens.muted, size: 32),
              const SizedBox(height: 10),
              Text(
                "No places in Guiuan match “${_queryController.text.trim()}”.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: DesignTokens.text, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                "FindMeTricycle only operates within Guiuan. Try another name, or go back and tap the spot on the map.",
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: DesignTokens.muted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: DesignTokens.border,
      ),
      itemBuilder: (context, index) {
        final place = _results[index];
        return ListTile(
          leading: Icon(Icons.place_outlined, color: DesignTokens.muted),
          title: Text(
            place.name,
            style: TextStyle(
              color: DesignTokens.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: place.secondaryLabel.isEmpty
              ? null
              : Text(
                  place.secondaryLabel,
                  style: TextStyle(color: DesignTokens.muted),
                ),
          onTap: () => Navigator.pop(context, place),
        );
      },
    );
  }
}
