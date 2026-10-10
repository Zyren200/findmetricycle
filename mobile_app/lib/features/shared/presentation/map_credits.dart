import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../core/components/index.dart";

/// "Map" in Settings: which map the app uses, with the credit its data
/// licence requires ("© OpenStreetMap contributors"). The maps themselves
/// no longer show MapLibre's ⓘ button — it sat right above the tab bar
/// and kept getting tapped by mistake.
class MapCreditsSection extends StatelessWidget {
  const MapCreditsSection({super.key});

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel("Map"),
        SunListCard(children: [
          SunListRow(
            icon: Icons.map_outlined,
            label: "Map data",
            subtitle: "© OpenStreetMap contributors",
            onTap: () => _open("https://www.openstreetmap.org/copyright"),
          ),
          SunListRow(
            icon: Icons.layers_outlined,
            label: "Map style",
            subtitle: "OpenFreeMap · Liberty (light) and Dark",
            onTap: () => _open("https://openfreemap.org"),
          ),
          SunListRow(
            icon: Icons.explore_outlined,
            label: "Map engine",
            subtitle: "MapLibre",
            onTap: () => _open("https://maplibre.org"),
          ),
        ]),
      ],
    );
  }
}
