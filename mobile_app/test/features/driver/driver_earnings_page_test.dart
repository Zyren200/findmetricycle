import "package:findme_tricycle_mobile/core/network/api_client.dart";
import "package:findme_tricycle_mobile/core/network/socket_client.dart";
import "package:findme_tricycle_mobile/features/driver/presentation/driver_earnings_page.dart";
import "package:findme_tricycle_mobile/features/driver/presentation/driver_ride_controller.dart";
import "package:findme_tricycle_mobile/features/driver/repositories/driver_repository.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";

class _UnusedRepository extends DriverRepository {
  _UnusedRepository() : super(ApiClient());
}

DriverRideController controllerWith({
  required Map<String, dynamic> summary,
  List<Map<String, dynamic>> trips = const [],
}) {
  return DriverRideController(_UnusedRepository(), SocketClient())
    ..earningsSummary = summary
    ..performanceStats = {"completedRides": trips.length, "cancellationRate": 0, "fiveStarRatings": 1}
    ..completedRides = trips;
}

Future<void> pumpPage(WidgetTester tester, DriverRideController controller) async {
  // A typical phone viewport.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<DriverRideController>.value(
      value: controller,
      child: const MaterialApp(home: DriverEarningsPage()),
    ),
  );
}

void main() {
  testWidgets("shows today, week, month, chart and recent trips", (tester) async {
    final controller = controllerWith(
      summary: {
        "total_rides": 12,
        "total_earnings": 1845.5,
        "rating_avg": 4.8,
        "today": {"rides": 3, "earnings": 150},
        "week": {"rides": 7, "earnings": 520.25},
        "month": {"rides": 12, "earnings": 1845.5},
        "daily": [
          for (var i = 0; i < 7; i++)
            {"date": "2026-09-${20 + i}", "rides": i, "earnings": i * 40.0},
        ],
      },
      trips: [
        {
          "id": 41,
          "final_fare": 55,
          "pickup_address": "Plaza",
          "dropoff_address": "Palengke",
          "distance_km": 2.4,
          "completed_at": "2026-09-26T09:15:00",
        },
      ],
    );
    await pumpPage(tester, controller);

    expect(find.text("₱150.00"), findsOneWidget); // today
    expect(find.text("3 rides completed"), findsOneWidget);
    expect(find.text("₱520.25"), findsOneWidget); // week
    expect(find.text("Kabuuan: ₱840.00"), findsOneWidget); // 7-day total (0+40+…+240)

    // Completed ride: destination as the title, pickup and distance below.
    await tester.scrollUntilVisible(find.text("Palengke"), 300);
    expect(find.text("₱55.00"), findsOneWidget);
    expect(find.textContaining("From Plaza · 2.4 km"), findsOneWidget);
    expect(tester.takeException(), isNull); // no layout overflow
  });

  testWidgets("a new rider with no trips sees zeros, not errors", (tester) async {
    final controller = controllerWith(summary: {});
    await pumpPage(tester, controller);

    expect(find.text("₱0.00"), findsWidgets);
    await tester.scrollUntilVisible(find.text("No completed rides yet"), 300);
    expect(tester.takeException(), isNull);
  });
}
