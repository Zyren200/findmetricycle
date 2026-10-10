import "package:flutter_test/flutter_test.dart";
import "package:findme_tricycle_mobile/core/utils/geocoding.dart";
import "package:findme_tricycle_mobile/core/utils/ride_format.dart";

// Trimmed from real Nominatim / Photon answers for points in Guiuan.
String? nominatim(Map<String, dynamic> data) =>
    parseNominatimPlace(data)?.format(fallbackTown: kServiceAreaTown);

void main() {
  group("parseNominatimPlace", () {
    test("landmark, street, purok, barangay, town and province", () {
      expect(
        nominatim({
          "category": "amenity",
          "addresstype": "amenity",
          "name": "Guiuan National High School",
          "address": {
            "amenity": "Guiuan National High School",
            "road": "Borongan – Guiuan Road",
            "neighbourhood": "Purok 2",
            "quarter": "Poblacion Ward 10",
            "suburb": "Poblacion Ward",
            "town": "Guiuan",
            "state": "Eastern Samar",
          },
        }),
        "Guiuan National High School, Borongan – Guiuan Road, Purok 2, "
        "Brgy. Poblacion Ward 10, Guiuan, Eastern Samar",
      );
    });

    test("rural barangay gets its town and its sitio", () {
      expect(
        nominatim({
          "category": "highway",
          "addresstype": "road",
          "name": "",
          "address": {
            "quarter": "Hollywood",
            "suburb": "Poblacion Ward",
            "village": "Salug",
            "state": "Eastern Samar",
          },
        }),
        "Hollywood, Brgy. Salug, Guiuan, Eastern Samar",
      );
      expect(
        nominatim({
          "category": "highway",
          "addresstype": "road",
          "name": "",
          "address": {
            "hamlet": "Lapa",
            "village": "San Juan",
            "state": "Eastern Samar",
          },
        }),
        "Lapa, Brgy. San Juan, Guiuan, Eastern Samar",
      );
    });

    test("a barangay itself isn't repeated as a landmark", () {
      expect(
        nominatim({
          "category": "place",
          "addresstype": "village",
          "name": "Sulangan",
          "address": {"village": "Sulangan", "state": "Eastern Samar"},
        }),
        "Brgy. Sulangan, Guiuan, Eastern Samar",
      );
    });

    test("unnamed road inside named grounds uses the grounds", () {
      expect(
        nominatim({
          "category": "highway",
          "addresstype": "road",
          "name": "",
          "address": {
            "industrial": "Guiuan Municipal Wharf",
            "quarter": "Poblacion Ward 6",
            "suburb": "Poblacion Ward",
            "town": "Guiuan",
            "state": "Eastern Samar",
          },
        }),
        "Guiuan Municipal Wharf, Brgy. Poblacion Ward 6, Guiuan, Eastern Samar",
      );
    });

    test("OSM's own town wins over the fallback", () {
      expect(
        parseNominatimPlace({
          "category": "highway",
          "name": "Rizal Avenue",
          "address": {
            "road": "Rizal Avenue",
            "village": "Poblacion",
            "town": "Mercedes",
            "state": "Eastern Samar",
          },
        })?.format(fallbackTown: kServiceAreaTown),
        "Rizal Avenue, Brgy. Poblacion, Mercedes, Eastern Samar",
      );
    });

    test("no address means no place", () {
      expect(parseNominatimPlace({"error": "Unable to geocode"}), isNull);
    });
  });

  group("parsePhotonPlace", () {
    test("a city that isn't the town is the barangay", () {
      expect(
        parsePhotonPlace({
          "osm_key": "office",
          "name": "Salug Barangay Hall",
          "street": "Guimbaolibot Avenue",
          "city": "Salug",
          "state": "Eastern Samar",
        }, fallbackTown: kServiceAreaTown)
            ?.format(fallbackTown: kServiceAreaTown),
        "Salug Barangay Hall, Guimbaolibot Avenue, Brgy. Salug, Guiuan, "
        "Eastern Samar",
      );
    });

    test("a village feature is the barangay", () {
      expect(
        parsePhotonPlace({
          "osm_key": "place",
          "osm_value": "village",
          "name": "Cambante",
          "state": "Eastern Samar",
        }, fallbackTown: kServiceAreaTown)
            ?.format(fallbackTown: kServiceAreaTown),
        "Brgy. Cambante, Guiuan, Eastern Samar",
      );
    });
  });

  test("format with a searched landmark", () {
    const place = PlaceParts(
      street: "Guimbaolibot Avenue",
      barangay: "Brgy. Salug",
      province: "Eastern Samar",
    );
    expect(
      place.format(landmark: "Salug Basketball Court", fallbackTown: "Guiuan"),
      "Salug Basketball Court, Guimbaolibot Avenue, Brgy. Salug, Guiuan, "
      "Eastern Samar",
    );
  });

  test("splitPlaceLabel", () {
    final label =
        splitPlaceLabel("Lapa, Brgy. San Juan, Guiuan, Eastern Samar");
    expect(label.title, "Lapa");
    expect(label.detail, "Brgy. San Juan, Guiuan, Eastern Samar");
    expect(splitPlaceLabel(kPinnedPlaceLabel).detail, isNull);
  });
}
