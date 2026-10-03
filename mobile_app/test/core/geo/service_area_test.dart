import "dart:convert";
import "dart:io";

import "package:findme_tricycle_mobile/core/geo/service_area.dart";
import "package:findme_tricycle_mobile/core/utils/place_search.dart";
import "package:flutter_test/flutter_test.dart";
import "package:latlong2/latlong.dart" as ll;

/// The copy bundled with the app (exported from the backend).
ServiceArea bundledArea({bool? enforced}) {
  final json = jsonDecode(
          File("assets/service_area/service_area.json").readAsStringSync())
      as Map<String, dynamic>;
  if (enforced != null) json["enforced"] = enforced;
  return ServiceArea.fromJson(json);
}

void main() {
  final area = bundledArea();

  // Island points are barangay pins on that island.
  const inside = {
    "the town proper": ll.LatLng(11.0311, 125.7235),
    "Homonhon Island": ll.LatLng(10.742, 125.7223),
    "Suluan Island": ll.LatLng(10.7612, 125.9508),
    "Calicoan Island": ll.LatLng(10.9397, 125.8262),
    "Manicani Island": ll.LatLng(11.0033, 125.6282),
    "Tubabao Island": ll.LatLng(11.0449, 125.6857),
  };
  const outside = {
    "Mercedes": ll.LatLng(11.105, 125.7185),
    "Borongan": ll.LatLng(11.608, 125.432),
    "Tacloban": ll.LatLng(11.244, 125.004),
    "the sea east of Suluan": ll.LatLng(10.7612, 125.99),
  };

  test("the bundled copy is Guiuan with every island", () {
    expect(area.polygons, hasLength(33));
    expect(area.enforced, isTrue);
    expect(area.raw["bundled"], isTrue);
    expect(area.contains(area.center, bufferMeters: 0), isTrue);
  });

  for (final entry in inside.entries) {
    test("${entry.key} is inside", () {
      expect(area.contains(entry.value), isTrue);
    });
  }

  for (final entry in outside.entries) {
    test("${entry.key} is outside", () {
      expect(area.contains(entry.value), isFalse);
    });
  }

  test("just past the Mercedes border counts as inside only within the buffer",
      () {
    const nearBorder = ll.LatLng(11.08149, 125.7235);
    expect(area.contains(nearBorder, bufferMeters: 0), isFalse);
    expect(area.contains(nearBorder), isTrue); // 300 m buffer
  });

  test("invalid coordinates are never inside", () {
    expect(area.contains(const ll.LatLng(double.nan, 125.72)), isFalse);
  });

  test("blocks outside points only while the service area is enforced", () {
    final mercedes = outside["Mercedes"]!;
    expect(bundledArea(enforced: true).blocks(mercedes), isTrue);
    expect(bundledArea(enforced: false).blocks(mercedes), isFalse);
    expect(bundledArea(enforced: true).blocks(inside["the town proper"]!),
        isFalse);
  });

  test("the dimmed mask is the world with Guiuan's 33 outlines cut out", () {
    final geometry = (area.outsideMaskGeoJson["features"] as List).first["geometry"]
        as Map<String, dynamic>;
    expect(geometry["type"], "Polygon");
    expect(geometry["coordinates"] as List, hasLength(34));
  });

  test("search asks Photon for a box around all of Guiuan", () {
    final box = area.photonBbox.split(",").map(double.parse).toList();
    expect(box[0] <= area.bbox[0] && box[1] <= area.bbox[1], isTrue);
    expect(box[2] >= area.bbox[2] && box[3] >= area.bbox[3], isTrue);
    expect(box[2] - box[0], lessThan(0.4)); // not all of Samar
  });

  test("search keeps only places inside Guiuan", () {
    final suggestions = [
      const PlaceSuggestion(
          name: "Guiuan Church", secondaryLabel: "", lat: 11.0335, lng: 125.7245),
      const PlaceSuggestion(
          name: "Mercedes Plaza", secondaryLabel: "", lat: 11.105, lng: 125.7185),
      const PlaceSuggestion(
          name: "Calicoan Surf Camp", secondaryLabel: "", lat: 10.9397, lng: 125.8262),
      const PlaceSuggestion(
          name: "Tacloban Airport", secondaryLabel: "", lat: 11.2276, lng: 125.0279),
    ];
    expect(keepInsideServiceArea(suggestions, area).map((s) => s.name),
        ["Guiuan Church", "Calicoan Surf Camp"]);
  });
}
