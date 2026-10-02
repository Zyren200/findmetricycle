/// Display helpers shared by the passenger and rider ride-history screens.
library;

const String kPinnedPlaceLabel = "Naka-pin sa mapa";

final RegExp _coordinatePattern =
    RegExp(r"^\s*-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+\s*$");

bool looksLikeCoordinates(String? text) =>
    text != null && _coordinatePattern.hasMatch(text);

/// Older bookings stored raw coordinates as the address; show those as a
/// pinned spot instead of a string of numbers.
String placeLabel(dynamic raw) {
  final text = raw?.toString().trim();
  if (text == null || text.isEmpty || looksLikeCoordinates(text)) {
    return kPinnedPlaceLabel;
  }
  return text;
}

const List<String> _months = [
  "Ene",
  "Peb",
  "Mar",
  "Abr",
  "May",
  "Hun",
  "Hul",
  "Ago",
  "Set",
  "Okt",
  "Nob",
  "Dis",
];

/// "Set 26, 2026 • 2:06 PM" in the phone's local time, or null.
String? formatRideDateTime(dynamic raw) {
  final date = DateTime.tryParse(raw?.toString() ?? "")?.toLocal();
  if (date == null) return null;
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, "0");
  final period = date.hour < 12 ? "AM" : "PM";
  return "${_months[date.month - 1]} ${date.day}, ${date.year} • $hour:$minute $period";
}

String peso(double value) => "₱${value.toStringAsFixed(2)}";

int toInt(dynamic v) => int.tryParse(v?.toString() ?? "") ?? 0;
double toDouble(dynamic v) => double.tryParse(v?.toString() ?? "") ?? 0;
