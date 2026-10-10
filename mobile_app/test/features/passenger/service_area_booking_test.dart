import "dart:convert";
import "dart:io";

import "package:findme_tricycle_mobile/core/geo/service_area.dart";
import "package:findme_tricycle_mobile/core/network/api_client.dart";
import "package:findme_tricycle_mobile/core/network/socket_client.dart";
import "package:findme_tricycle_mobile/core/state/service_area_store.dart";
import "package:findme_tricycle_mobile/features/passenger/presentation/passenger_ride_controller.dart";
import "package:findme_tricycle_mobile/features/passenger/repositories/passenger_repository.dart";
import "package:flutter_test/flutter_test.dart";
import "package:latlong2/latlong.dart" as ll;

class _FakeSocketClient extends SocketClient {
  @override
  Stream<dynamic> on(String event) => const Stream.empty();

  @override
  Future<dynamic> emit(String event, [dynamic payload]) async => null;
}

class _FakeRepository extends PassengerRepository {
  _FakeRepository() : super(ApiClient());

  int findRideCalls = 0;
  Map<String, dynamic> findRideResponse = {"success": false};

  @override
  Future<Map<String, dynamic>> findRide({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    int passengerCount = 1,
    double? routeDistanceKm,
    bool autoAssign = true,
  }) async {
    findRideCalls++;
    return findRideResponse;
  }
}

ServiceArea _area({required bool enforced}) {
  final json = jsonDecode(
          File("assets/service_area/service_area.json").readAsStringSync())
      as Map<String, dynamic>;
  json["enforced"] = enforced;
  return ServiceArea.fromJson(json);
}

const town = ll.LatLng(11.0311, 125.7235);
const homonhon = ll.LatLng(10.742, 125.7223);
const mercedes = ll.LatLng(11.105, 125.7185);
const tacloban = ll.LatLng(11.244, 125.004);

void main() {
  // Address lookups and road snapping get flutter_test's offline HTTP.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepository repo;
  late PassengerRideController controller;

  PassengerRideController make({required bool enforced}) {
    repo = _FakeRepository();
    return controller = PassengerRideController(
      repo,
      _FakeSocketClient(),
      serviceAreaStore: ServiceAreaStore.withArea(_area(enforced: enforced)),
    );
  }

  tearDown(() => controller.dispose());

  group("while the service area is enforced", () {
    test("a map tap outside Guiuan is refused with a clear message", () async {
      final c = make(enforced: true);
      await c.selectOnMap(mercedes, asPickup: true);
      expect(c.error, ServiceArea.outsideMessage);
      expect(c.pickup, isNull);
    });

    test("GPS outside Guiuan isn't used as the pickup", () {
      final c = make(enforced: true);
      c.currentPosition = mercedes;
      expect(c.isOutsideServiceArea, isTrue);
      c.usePickupAtCurrentLocation();
      expect(c.pickup, isNull);
      expect(c.error, ServiceArea.outsideMessage);
    });

    test("a saved place outside Guiuan isn't set as the destination", () {
      final c = make(enforced: true);
      c.pickup = town;
      expect(
          c.setDestinationFromFavorite(tacloban, address: "Tacloban"), isFalse);
      expect(c.dropoff, isNull);
      expect(c.error, ServiceArea.outsideMessage);
    });

    test("an outside drop-off never reaches the server", () async {
      final c = make(enforced: true);
      c.pickup = town;
      c.dropoff = tacloban;
      await c.findRide();
      expect(repo.findRideCalls, 0);
      expect(c.error, ServiceArea.outsideMessage);
    });

    test("a trip from the town to an island goes to the server", () async {
      final c = make(enforced: true);
      c.pickup = town;
      c.dropoff = homonhon;
      await c.findRide();
      expect(repo.findRideCalls, 1);
    });
  });

  group("while it isn't enforced (testing from outside Guiuan)", () {
    test("outside points are allowed, with the notice still on", () {
      final c = make(enforced: false);
      c.currentPosition = mercedes;
      c.pickup = mercedes;
      expect(c.isOutsideServiceArea, isTrue);
      expect(c.serviceAreaEnforced, isFalse);
      expect(
          c.setDestinationFromFavorite(tacloban, address: "Tacloban"), isTrue);
      expect(c.dropoff, tacloban);
      expect(c.error, isNull);
    });
  });

  test("a booking the server refuses shows the server's message", () async {
    final c = make(enforced: false);
    c.pickup = mercedes;
    c.dropoff = town;
    repo.findRideResponse = {
      "success": false,
      "message":
          "Sorry, FindMeTricycle only operates within Guiuan. Please choose a pickup point inside Guiuan.",
    };
    await c.findRide();
    expect(repo.findRideCalls, 1);
    expect(c.error, contains("only operates within Guiuan"));
  });
}
