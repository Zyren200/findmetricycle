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

/// Splits "Guimbaolibot Avenue, Brgy. Poblacion Ward 9-A, Guiuan, Eastern
/// Samar" into its most specific part and the rest, for a two-line label.
({String title, String? detail}) splitPlaceLabel(String label) {
  final comma = label.indexOf(", ");
  if (comma <= 0) return (title: label, detail: null);
  return (title: label.substring(0, comma), detail: label.substring(comma + 2));
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

/// "₱1,845.50" — pesos with thousands separators and centavos.
String peso(double value) => "₱${groupThousands(value.toStringAsFixed(2))}";

/// "38450.00" → "38,450.00".
String groupThousands(String number) {
  final negative = number.startsWith("-");
  final digits = negative ? number.substring(1) : number;
  final dot = digits.indexOf(".");
  final whole = dot < 0 ? digits : digits.substring(0, dot);
  final rest = dot < 0 ? "" : digits.substring(dot);
  final grouped = whole.replaceAllMapped(
      RegExp(r"\B(?=(\d{3})+(?!\d))"), (_) => ",");
  return "${negative ? "-" : ""}$grouped$rest";
}

int toInt(dynamic v) => int.tryParse(v?.toString() ?? "") ?? 0;
double toDouble(dynamic v) => double.tryParse(v?.toString() ?? "") ?? 0;
