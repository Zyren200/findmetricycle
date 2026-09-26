import "dart:async";

import "package:findme_tricycle_mobile/core/network/api_client.dart";
import "package:findme_tricycle_mobile/core/network/socket_client.dart";
import "package:findme_tricycle_mobile/features/shared/presentation/notifications_screen.dart";
import "package:findme_tricycle_mobile/features/shared/state/notifications_controller.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

class FakeApi extends ApiClient {
  final List<String> posted = [];
  List<Map<String, dynamic>> rows = [];

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async => {
        "success": true,
        "data": rows,
        "meta": {"unread": rows.where((r) => r["is_read"] == 0).length},
      };

  @override
  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? data, Map<String, dynamic>? queryParameters}) async {
    posted.add(path);
    return {"success": true, "meta": {"unread": 0}};
  }
}

class FakeSocket extends SocketClient {
  final _live = StreamController<dynamic>.broadcast();

  @override
  Stream<dynamic> on(String event) => _live.stream;

  void push(Map<String, dynamic> n) => _live.add(n);
}

Map<String, dynamic> row(int id, String type, String title, {bool read = false, String? at}) => {
      "id": id,
      "type": type,
      "title": title,
      "body": "Body $id",
      "is_read": read ? 1 : 0,
      "created_at": at ?? DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
    };

void main() {
  late FakeApi api;
  late FakeSocket socket;
  late NotificationsController ctrl;

  setUp(() {
    api = FakeApi()
      ..rows = [
        row(3, "booking_accepted", "Driver assigned"),
        row(2, "ride_completed", "Trip completed", read: true),
      ];
    socket = FakeSocket();
    ctrl = NotificationsController(api, socket, role: "passenger");
  });

  test("loads the list and the unread count", () async {
    await ctrl.load();
    expect(ctrl.items, hasLength(2));
    expect(ctrl.unread, 1);
  });

  test("mark all read saves to the server for this mode", () async {
    await ctrl.load();
    await ctrl.markAllRead();
    expect(ctrl.unread, 0);
    expect(api.posted, ["/passenger/notifications/read"]);
  });

  test("new notifications arrive live, but only for this mode", () async {
    await ctrl.load();
    socket.push({"id": 9, "type": "ride_request", "title": "New ride request", "recipientRole": "driver"});
    socket.push({"id": 10, "type": "driver_arrived", "title": "Your driver has arrived", "recipientRole": "passenger"});
    await Future<void>.delayed(Duration.zero);

    expect(ctrl.items.first["id"], 10);
    expect(ctrl.items.any((n) => n["id"] == 9), isFalse);
    expect(ctrl.unread, 2);
  });

  test("time labels are readable", () {
    final now = DateTime(2026, 9, 26, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 20)).toIso8601String(), now: now), "Ngayon lang");
    expect(timeAgo(now.subtract(const Duration(minutes: 5)).toIso8601String(), now: now), "5 min ang nakalipas");
    expect(timeAgo(now.subtract(const Duration(hours: 3)).toIso8601String(), now: now), "3 oras ang nakalipas");
    expect(timeAgo(now.subtract(const Duration(days: 1)).toIso8601String(), now: now), "Kahapon");
    expect(timeAgo("2026-08-01T10:00:00", now: now), "Ago 1, 2026");
  });

  testWidgets("opening the screen shows times and marks everything read", (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: NotificationsScreen(controller: ctrl)));
    await tester.pumpAndSettle();

    expect(find.text("Driver assigned"), findsOneWidget);
    expect(find.text("5 min ang nakalipas"), findsNWidgets(2));
    expect(ctrl.unread, 0);
    expect(api.posted, contains("/passenger/notifications/read"));
    expect(tester.takeException(), isNull);
  });

  testWidgets("bell shows the unread count", (tester) async {
    await ctrl.load();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: NotificationBell(controller: ctrl, onPressed: () {})),
    ));
    expect(find.text("1"), findsOneWidget);
  });
}
