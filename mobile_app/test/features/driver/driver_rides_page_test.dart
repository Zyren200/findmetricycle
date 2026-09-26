import "package:findme_tricycle_mobile/core/network/api_client.dart";
import "package:findme_tricycle_mobile/core/network/socket_client.dart";
import "package:findme_tricycle_mobile/features/driver/presentation/driver_ride_controller.dart";
import "package:findme_tricycle_mobile/features/driver/presentation/driver_rides_page.dart";
import "package:findme_tricycle_mobile/features/driver/repositories/driver_repository.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";

class FakeRidesRepository extends DriverRepository {
  FakeRidesRepository() : super(ApiClient());

  int historyCalls = 0;

  @override
  Future<Map<String, dynamic>> getRideHistory({
    int limit = 20,
    int offset = 0,
    String? status,
  }) async {
    historyCalls++;
    return {
      "success": true,
      "data": [
        {
          "id": 21,
          "status": "completed",
          "pickup_address": "Guiuan Plaza",
          "dropoff_address": "Guiuan Public Market",
          "distance_km": "2.345",
          "final_fare": "55.00",
          "passenger_count": 2,
          "completed_at": "2026-09-26T07:10:00.000Z",
          "passenger_name": "Armae Corpuz",
          "passenger_rating": 4,
          "passenger_feedback": "Mabilis at maingat",
        },
        {
          "id": 7,
          "status": "cancelled",
          "cancelled_by": "driver",
          "pickup_address": "11.10853, 125.38810",
          "dropoff_address": "11.11009, 125.38123",
          "distance_km": "0.770",
          "estimated_fare": "24.23",
          "cancelled_at": "2026-09-26T06:30:00.000Z",
          "passenger_name": "Armae Corpuz",
        },
        {
          "id": 2,
          "status": "cancelled",
          "cancelled_by": "passenger",
          "pickup_address": "Airport",
          "dropoff_address": "Pier",
          "passenger_name": "Juan",
        },
      ],
      "meta": {"completed": 1, "cancelled": 2, "totalEarned": 55, "hasMore": false},
    };
  }
}

void main() {
  late FakeRidesRepository repo;
  late ValueNotifier<int> navIndex;

  Future<void> pumpRides(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    repo = FakeRidesRepository();
    navIndex = ValueNotifier<int>(1);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ValueNotifier<int>>.value(value: navIndex),
          ChangeNotifierProvider(
            create: (_) => DriverRideController(repo, SocketClient()),
          ),
        ],
        child: const MaterialApp(home: DriverRidesPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("shows completed and cancelled trips readably", (tester) async {
    await pumpRides(tester);

    expect(find.text("NATAPOS"), findsOneWidget);
    expect(find.text("NO-SHOW"), findsOneWidget);
    expect(find.text("KINANSELA"), findsOneWidget);
    expect(find.text("+₱55.00"), findsOneWidget);
    expect(find.text("₱55.00"), findsOneWidget); // total earned
    expect(find.text("Armae Corpuz (+1 kasama)"), findsOneWidget);
    expect(find.text("“Mabilis at maingat”"), findsOneWidget);
    expect(find.text("Walang dumating na pasahero"), findsOneWidget);
    expect(find.text("Kinansela ng pasahero"), findsOneWidget);
    expect(find.textContaining("11.10853"), findsNothing);
    expect(find.textContaining("T07:"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("filters to completed trips", (tester) async {
    await pumpRides(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, "Natapos"));
    await tester.pumpAndSettle();

    expect(find.text("NATAPOS"), findsOneWidget);
    expect(find.text("KINANSELA"), findsNothing);
    expect(find.text("NO-SHOW"), findsNothing);
  });

  testWidgets("reloads when the Rides tab is opened again", (tester) async {
    await pumpRides(tester);
    final before = repo.historyCalls;

    navIndex.value = 0;
    navIndex.value = 1;
    await tester.pumpAndSettle();

    expect(repo.historyCalls, greaterThan(before));
  });
}
