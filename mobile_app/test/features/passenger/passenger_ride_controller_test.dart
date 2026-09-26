import "dart:async";

import "package:findme_tricycle_mobile/core/network/api_client.dart";
import "package:findme_tricycle_mobile/core/network/socket_client.dart";
import "package:findme_tricycle_mobile/features/passenger/presentation/passenger_ride_controller.dart";
import "package:findme_tricycle_mobile/features/passenger/repositories/passenger_repository.dart";
import "package:flutter_test/flutter_test.dart";
import "package:latlong2/latlong.dart" as ll;

/// Socket stand-in: tests push server events through [push].
class FakeSocketClient extends SocketClient {
  final Map<String, StreamController<dynamic>> _streams = {};

  @override
  Stream<dynamic> on(String event) =>
      (_streams[event] ??= StreamController<dynamic>.broadcast()).stream;

  @override
  Future<dynamic> emit(String event, [dynamic payload]) async => null;

  void push(String event, dynamic data) => _streams[event]?.add(data);
}

/// Repository stand-in returning canned API bodies.
class FakePassengerRepository extends PassengerRepository {
  FakePassengerRepository() : super(ApiClient());

  Map<String, dynamic> findRideResponse = {};
  Map<String, dynamic> chooseResponse = {};
  Map<String, dynamic> nearbyResponse = {};
  Map<String, dynamic> activeResponse = {"success": true, "data": null};
  final List<int> chosenDriverIds = [];

  @override
  Future<Map<String, dynamic>> getFareSettings() async => {"success": false};

  @override
  Future<Map<String, dynamic>> findRide({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    int passengerCount = 1,
    bool autoAssign = true,
  }) async =>
      findRideResponse;

  @override
  Future<Map<String, dynamic>> chooseDriver({
    required int bookingId,
    required int driverId,
  }) async {
    chosenDriverIds.add(driverId);
    return chooseResponse;
  }

  @override
  Future<Map<String, dynamic>> getNearbyDrivers(int bookingId) async =>
      nearbyResponse;

  @override
  Future<Map<String, dynamic>> getActiveBooking() async => activeResponse;
}

Map<String, dynamic> rider(int id, String name, double km) => {
      "id": id,
      "full_name": name,
      "tricycle_number": "TRI-$id",
      "rating": 4.5,
      "current_lat": 11.03,
      "current_lng": 125.72,
      "distanceToPickupKm": km,
    };

Map<String, dynamic> pendingBooking({int? driverId}) => {
      "id": 10,
      "status": "pending",
      "driver_id": driverId,
    };

void main() {
  late FakePassengerRepository repo;
  late FakeSocketClient socket;
  late PassengerRideController controller;

  setUp(() async {
    repo = FakePassengerRepository();
    socket = FakeSocketClient();
    controller = PassengerRideController(repo, socket);
    // GPS isn't available under test; initialize() must still wire up the
    // socket listeners.
    await controller.initialize();
    controller.pickup = const ll.LatLng(11.033, 125.722);
    controller.dropoff = const ll.LatLng(11.04, 125.74);
  });

  tearDown(() => controller.dispose());

  Future<void> findRideWith(List<Map<String, dynamic>> riders) async {
    repo.findRideResponse = {
      "success": true,
      "data": {
        "booking": pendingBooking(),
        "pickupPin": "1234",
        "nearbyDrivers": riders,
      },
    };
    await controller.findRide();
  }

  test("find ride lists the nearest online riders to choose from", () async {
    await findRideWith([rider(1, "Ana", 0.3), rider(2, "Ben", 1.1)]);

    expect(controller.isChoosingDriver, isTrue);
    expect(controller.nearbyDrivers.map((d) => d["full_name"]), ["Ana", "Ben"]);
    expect(controller.pickupPin, "1234");
  });

  test("no online riders keeps the passenger in the choose step", () async {
    await findRideWith([]);

    expect(controller.isChoosingDriver, isTrue);
    expect(controller.nearbyDrivers, isEmpty);
    expect(controller.rideNotice, contains("Walang online na rider"));
  });

  test("choosing a rider waits for that rider's answer", () async {
    await findRideWith([rider(1, "Ana", 0.3)]);
    repo.chooseResponse = {
      "success": true,
      "data": {"booking": pendingBooking(driverId: 1), "driver": rider(1, "Ana", 0.3)},
    };

    await controller.chooseDriver(1);

    expect(repo.chosenDriverIds, [1]);
    expect(controller.isWaitingForDriverResponse, isTrue);
    expect(controller.driverName, "Ana");
    expect(controller.nearbyDrivers, isEmpty);
  });

  test("a rejected choice keeps the passenger choosing with an error", () async {
    await findRideWith([rider(1, "Ana", 0.3)]);
    repo.chooseResponse = {
      "success": false,
      "message": "This rider is no longer available. Please choose another rider.",
    };

    await controller.chooseDriver(1);

    expect(controller.isChoosingDriver, isTrue);
    expect(controller.driverInfo, isNull);
    expect(controller.error, contains("no longer available"));
  });

  test("rider declining reopens the picker with a fresh list", () async {
    await findRideWith([rider(1, "Ana", 0.3), rider(2, "Ben", 1.1)]);
    repo.chooseResponse = {
      "success": true,
      "data": {"booking": pendingBooking(driverId: 1), "driver": rider(1, "Ana", 0.3)},
    };
    await controller.chooseDriver(1);
    final pickerRequests = controller.driverPickerRequest;

    socket.push("passenger:booking_update", {
      "booking": pendingBooking(),
      "nearbyDrivers": [rider(2, "Ben", 1.1)],
      "reason": "declined",
    });
    await Future<void>.delayed(Duration.zero);

    expect(controller.isChoosingDriver, isTrue);
    expect(controller.driverPickerRequest, pickerRequests + 1);
    expect(controller.nearbyDrivers.map((d) => d["id"]), [2]);
    expect(controller.rideNotice, contains("Ana"));
  });

  test("rider accepting keeps the rider's id, not the booking's", () async {
    await findRideWith([rider(7, "Ana", 0.3)]);
    repo.chooseResponse = {
      "success": true,
      "data": {"booking": pendingBooking(driverId: 7), "driver": rider(7, "Ana", 0.3)},
    };
    await controller.chooseDriver(7);

    socket.push("passenger:booking_update", {
      "booking": {
        "id": 10,
        "status": "accepted",
        "driver_id": 7,
        "driver_name": "Ana",
        "current_lat": 11.031,
        "current_lng": 125.721,
      },
    });
    await Future<void>.delayed(Duration.zero);

    expect(controller.bookingStatus, "accepted");
    expect(controller.driverInfo?["id"], 7);
    expect(controller.rideNotice, contains("Tinanggap"));
  });

  test("the choose list refreshes from the server", () async {
    await findRideWith([]);
    repo.nearbyResponse = {
      "success": true,
      "data": {
        "booking": pendingBooking(),
        "nearbyDrivers": [rider(3, "Cora", 0.8)],
      },
    };

    await controller.refreshNearbyDrivers();

    expect(controller.nearbyDrivers.map((d) => d["full_name"]), ["Cora"]);
  });

  group("pickup PIN", () {
    test("comes back after an app restart", () async {
      final restartedRepo = FakePassengerRepository()
        ..activeResponse = {
          "success": true,
          "data": {
            "booking": {
              "id": 10,
              "status": "accepted",
              "driver_id": 7,
              "pickup_lat": 11.033,
              "pickup_lng": 125.722,
              "dropoff_lat": 11.04,
              "dropoff_lng": 125.74,
            },
            "pickupPin": "4821",
            "driver": rider(7, "Ana", 0.3),
            "nearbyDrivers": [],
          },
        };
      final restarted = PassengerRideController(restartedRepo, FakeSocketClient());
      await restarted.initialize();

      expect(restarted.activeBookingId, 10);
      expect(restarted.pickupPin, "4821");
      expect(restarted.shouldShowPickupPin, isTrue);
      expect(restarted.driverName, "Ana");
      restarted.dispose();
    });

    test("rider arrival re-sends the PIN and asks the page to show it", () async {
      await findRideWith([rider(1, "Ana", 0.3)]);
      controller.pickupPin = null; // e.g. lost somehow
      final prompts = controller.pinPromptRequest;

      socket.push("passenger:driver_arrived", {"bookingId": 10, "pickupPin": "7302"});
      await Future<void>.delayed(Duration.zero);

      expect(controller.bookingStatus, "arriving");
      expect(controller.pickupPin, "7302");
      expect(controller.pinPromptRequest, prompts + 1);
      expect(controller.shouldShowPickupPin, isTrue);
    });

    test("is hidden once the trip has started", () async {
      await findRideWith([rider(1, "Ana", 0.3)]);
      controller.bookingStatus = "ongoing";

      expect(controller.shouldShowPickupPin, isFalse);
    });
  });
}
