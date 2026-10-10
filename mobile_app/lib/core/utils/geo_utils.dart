import "dart:math";

double _toRad(double deg) => deg * pi / 180;

double haversineKm({
  required double lat1,
  required double lng1,
  required double lat2,
  required double lng2,
}) {
  const earthRadiusKm = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return double.parse((earthRadiusKm * c).toStringAsFixed(3));
}

double calculateFare({
  required double distanceKm,
  required double baseFare,
  required double perKmRate,
  int passengerCount = 1,
  double additionalPassengerFee = 0,
  double minimumFare = 0,
}) {
  // Same formula as the server (backend/src/utils/fare.js).
  final singlePassengerFare = baseFare + (distanceKm * perKmRate);
  final additionalPassengersCharge =
      (passengerCount - 1).clamp(0, 1 << 30) * additionalPassengerFee;
  final total =
      max(singlePassengerFare + additionalPassengersCharge, minimumFare);
  return double.parse(total.toStringAsFixed(2));
}
