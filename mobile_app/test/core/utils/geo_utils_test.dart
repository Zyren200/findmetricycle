import "package:flutter_test/flutter_test.dart";
import "package:findme_tricycle_mobile/core/utils/geo_utils.dart";

void main() {
  group("haversineKm", () {
    test("returns zero for identical coordinates", () {
      final distance = haversineKm(
        lat1: 14.5995,
        lng1: 120.9842,
        lat2: 14.5995,
        lng2: 120.9842,
      );

      expect(distance, 0.0);
    });

    test("returns expected distance for one degree latitude", () {
      final distance = haversineKm(
        lat1: 0,
        lng1: 0,
        lat2: 1,
        lng2: 0,
      );

      expect(distance, closeTo(111.195, 0.01));
    });
  });

  group("calculateFare", () {
    test("calculates fare from base and per-km rate", () {
      final fare = calculateFare(
        distanceKm: 7.5,
        baseFare: 30,
        perKmRate: 12,
      );

      expect(fare, 120.0);
    });
  });
}
