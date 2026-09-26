import "package:findme_tricycle_mobile/core/network/api_client.dart";
import "package:findme_tricycle_mobile/core/network/socket_client.dart";
import "package:findme_tricycle_mobile/features/auth/repositories/auth_repository.dart";
import "package:findme_tricycle_mobile/features/passenger/presentation/pages/ride_history_page.dart";
import "package:findme_tricycle_mobile/features/passenger/presentation/passenger_profile_controller.dart";
import "package:findme_tricycle_mobile/features/passenger/presentation/passenger_ride_controller.dart";
import "package:findme_tricycle_mobile/features/passenger/repositories/favorites_repository.dart";
import "package:findme_tricycle_mobile/features/passenger/repositories/passenger_repository.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";

class FakeHistoryRepository extends PassengerRepository {
  FakeHistoryRepository() : super(ApiClient());

  int historyCalls = 0;

  @override
  Future<Map<String, dynamic>> getBookingHistory({int limit = 20, int offset = 0}) async {
    historyCalls++;
    return {
      "success": true,
      "data": [
        {
          "id": 12,
          "status": "completed",
          "pickup_address": "Guiuan Plaza",
          "dropoff_address": "Guiuan Public Market",
          "dropoff_lat": 11.03,
          "dropoff_lng": 125.72,
          "distance_km": "1.853",
          "estimated_fare": "20.19",
          "final_fare": "45.50",
          "requested_at": "2026-09-26T06:00:00.000Z",
          "completed_at": "2026-09-26T06:20:00.000Z",
          "driver_name": "Renz Jay",
          "tricycle_number": "AAJ-5974",
          "rating": null,
        },
        {
          "id": 7,
          "status": "cancelled",
          // Older bookings stored raw coordinates as the address.
          "pickup_address": "11.10853, 125.38810",
          "dropoff_address": "11.11009, 125.38123",
          "dropoff_lat": 11.11009,
          "dropoff_lng": 125.38123,
          "distance_km": "0.770",
          "estimated_fare": "24.23",
          "final_fare": null,
          "requested_at": "2026-09-26T06:06:19.000Z",
          "cancelled_by": "passenger",
        },
      ],
      "meta": {"total": 2, "completed": 1, "cancelled": 1, "totalSpent": 45.5, "hasMore": false},
    };
  }
}

void main() {
  late FakeHistoryRepository repo;
  late ValueNotifier<int> navIndex;

  Future<void> pumpHistory(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    repo = FakeHistoryRepository();
    navIndex = ValueNotifier<int>(1);
    final apiClient = ApiClient();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: apiClient),
          ChangeNotifierProvider<ValueNotifier<int>>.value(value: navIndex),
          ChangeNotifierProvider(
            create: (_) => PassengerRideController(repo, SocketClient()),
          ),
          ChangeNotifierProvider(
            create: (_) => PassengerProfileController(
              AuthRepository(apiClient),
              FavoritesRepository(apiClient),
            ),
          ),
        ],
        child: const MaterialApp(home: RideHistoryPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("shows readable history with totals, places and fares", (tester) async {
    await pumpHistory(tester);

    expect(find.text("₱45.50"), findsWidgets); // fare + total spent
    expect(find.text("NATAPOS"), findsOneWidget);
    expect(find.text("KINANSELA"), findsOneWidget);
    expect(find.text("Guiuan Plaza"), findsOneWidget);
    expect(find.textContaining("Renz Jay • AAJ-5974"), findsOneWidget);
    expect(find.text("Walang bayad"), findsOneWidget); // cancelled isn't charged
    expect(find.text("I-rate ang rider"), findsOneWidget); // completed, unrated
    // Raw coordinates and ISO timestamps are never shown.
    expect(find.textContaining("11.10853"), findsNothing);
    expect(find.text("Naka-pin sa mapa"), findsNWidgets(2));
    expect(find.textContaining("T06:"), findsNothing);
    expect(find.textContaining("1.9 km"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("filters by status", (tester) async {
    await pumpHistory(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, "Kinansela"));
    await tester.pumpAndSettle();

    expect(find.text("KINANSELA"), findsOneWidget);
    expect(find.text("NATAPOS"), findsNothing);
  });

  testWidgets("reloads when the passenger opens the History tab again", (tester) async {
    await pumpHistory(tester);
    final callsBefore = repo.historyCalls;

    navIndex.value = 0;
    navIndex.value = 1;
    await tester.pumpAndSettle();

    expect(repo.historyCalls, greaterThan(callsBefore));
  });
}
