import "dart:async";

import "package:findme_tricycle_mobile/core/network/api_client.dart";
import "package:findme_tricycle_mobile/core/network/socket_client.dart";
import "package:findme_tricycle_mobile/features/driver/presentation/driver_ride_controller.dart";
import "package:findme_tricycle_mobile/features/driver/repositories/driver_repository.dart";
import "package:flutter_test/flutter_test.dart";

class FakeSocketClient extends SocketClient {
  final Map<String, StreamController<dynamic>> _streams = {};

  @override
  Stream<dynamic> on(String event) =>
      (_streams[event] ??= StreamController<dynamic>.broadcast()).stream;

  @override
  Future<dynamic> emit(String event, [dynamic payload]) async => null;

  void push(String event, dynamic data) => _streams[event]?.add(data);
}

class FakeDriverRepository extends DriverRepository {
  FakeDriverRepository() : super(ApiClient());

  String approvalStatus = "approved";
  int profileLoads = 0;

  @override
  Future<Map<String, dynamic>> getProfile() async {
    profileLoads++;
    return {
      "success": true,
      "data": {"id": 5, "approval_status": approvalStatus, "is_online": 0},
    };
  }

  @override
  Future<Map<String, dynamic>> getRatings() async => {"success": true, "data": []};

  @override
  Future<Map<String, dynamic>> getCompletedRides() async =>
      {"success": true, "data": []};

  @override
  Future<Map<String, dynamic>> getEarnings() async => {"success": true, "data": {}};

  @override
  Future<Map<String, dynamic>> getPerformance() async =>
      {"success": true, "data": {}};

  @override
  Future<bool> checkConnectivity() async => true;
}

void main() {
  late FakeDriverRepository repo;
  late FakeSocketClient socket;
  late DriverRideController controller;

  setUp(() async {
    repo = FakeDriverRepository();
    socket = FakeSocketClient();
    controller = DriverRideController(repo, socket);
    // No GPS under test — like a rider indoors with no fix.
    await controller.initialize();
  });

  tearDown(() => controller.dispose());

  test("an approved rider's profile loads even when GPS fails", () {
    expect(controller.error, isNotNull); // the GPS problem is reported…
    expect(controller.driverProfile?["approval_status"], "approved"); // …but approval still loads
    expect(controller.isInitializing, isFalse);
  });

  test("an approval event is shown as approved and refreshes the profile", () async {
    final loadsBefore = repo.profileLoads;

    socket.push("driver:approval_status", {
      "status": "approved",
      "message": "Your account is approved. You can now go online.",
    });
    await Future<void>.delayed(Duration.zero);

    expect(controller.approvalStatus, "approved");
    expect(controller.approvalMessage, contains("approved"));
    expect(repo.profileLoads, greaterThan(loadsBefore));

    controller.dismissApprovalMessage();
    expect(controller.approvalMessage, isNull);
  });

  test("a rejection carries its reason", () async {
    socket.push("driver:approval_status", {
      "status": "rejected",
      "message": "Your account was rejected.",
      "reason": "Blurry license photo.",
    });
    await Future<void>.delayed(Duration.zero);

    expect(controller.approvalStatus, "rejected");
    expect(controller.approvalMessage, contains("Blurry license photo."));
  });
}
