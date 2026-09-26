import "dart:io";
import "dart:ui" as ui;

import "package:findme_tricycle_mobile/core/widgets/map_marker_icons.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

/// Loads the real Material Icons font so glyphs render (tests default to a
/// placeholder font), when the Flutter SDK's copy is available.
Future<void> _loadIconFont() async {
  final sdk = Platform.environment["FLUTTER_ROOT"];
  if (sdk == null) return;
  final file = File("$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf");
  if (!file.existsSync()) return;
  final loader = FontLoader("MaterialIcons")
    ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

Future<ui.Image> _decode(List<int> bytes) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  return (await codec.getNextFrame()).image;
}

void main() {
  setUpAll(_loadIconFont);

  test("pins and badges render at the device pixel ratio", () async {
    await TestWidgetsFlutterBinding.ensureInitialized().runAsync(() async {
      const ratio = 3.0;
      final pin = await MapMarkerIcons.pin(Colors.blue, Icons.person_rounded, ratio);
      final badge = await MapMarkerIcons.badge(Colors.green, Icons.two_wheeler_rounded, ratio);

      final pinImage = await _decode(pin);
      final badgeImage = await _decode(badge);
      // 38×50 and (34+4)×(34+4) logical pixels at 3x.
      expect([pinImage.width, pinImage.height], [114, 150]);
      expect([badgeImage.width, badgeImage.height], [114, 114]);

      // Optional: dump previews for a visual check.
      final out = Platform.environment["MARKER_PREVIEW_DIR"];
      if (out != null) {
        final previews = {
          "me": pin,
          "pickup": await MapMarkerIcons.pin(const Color(0xFF0E8C46), Icons.circle, ratio, glyphScale: 0.42),
          "dropoff": await MapMarkerIcons.pin(const Color(0xFFC94530), Icons.flag_rounded, ratio),
          "rider": badge,
          "assigned": await MapMarkerIcons.badge(const Color(0xFFF0B429), Icons.two_wheeler_rounded, ratio, diameter: 42),
        };
        for (final e in previews.entries) {
          File("$out/${e.key}.png").writeAsBytesSync(e.value);
        }
      }
    });
  });
}
