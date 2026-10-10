import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:findme_tricycle_mobile/core/safety/emergency_dialer.dart";
import "package:findme_tricycle_mobile/core/safety/sos_delivery.dart";
import "package:findme_tricycle_mobile/core/safety/sos_flow.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("SosDelivery", () {
    test("reports sent when the first attempt succeeds", () async {
      final delivery = SosDelivery(onChanged: () {});
      expect(await delivery.send(() async => true), isTrue);
      expect(delivery.status, SosDeliveryStatus.sent);
      delivery.dispose();
    });

    test("stays pending after a failure and delivers on retry", () async {
      var online = false;
      var attempts = 0;
      final delivery = SosDelivery(onChanged: () {});

      await delivery.send(() async {
        attempts++;
        return online;
      });
      expect(delivery.status, SosDeliveryStatus.pending);

      online = true;
      expect(await delivery.retry(), isTrue);
      expect(delivery.status, SosDeliveryStatus.sent);
      expect(attempts, 2);

      // Nothing left to send.
      expect(await delivery.retry(), isFalse);
      expect(attempts, 2);
      delivery.dispose();
    });

    test("a thrown error counts as not sent", () async {
      final delivery = SosDelivery(onChanged: () {});
      await delivery.send(() async => throw Exception("offline"));
      expect(delivery.status, SosDeliveryStatus.pending);
      delivery.dispose();
    });

    test("retries when the app returns to the foreground", () async {
      var attempts = 0;
      final delivery = SosDelivery(onChanged: () {});
      await delivery.send(() async => ++attempts > 1);
      expect(delivery.status, SosDeliveryStatus.pending);

      delivery.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(delivery.status, SosDeliveryStatus.sent);
      delivery.dispose();
    });

    test("retries on its own timer", () async {
      var attempts = 0;
      final delivery = SosDelivery(
          onChanged: () {}, retryEvery: const Duration(milliseconds: 20));
      await delivery.send(() async => ++attempts > 1);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(delivery.status, SosDeliveryStatus.sent);
      delivery.dispose();
    });

    test("dismiss hides a sent alert but never a pending one", () async {
      final delivery = SosDelivery(onChanged: () {});
      await delivery.send(() async => false);
      delivery.dismiss();
      expect(delivery.status, SosDeliveryStatus.pending);
      await delivery.send(() async => true);
      delivery.dismiss();
      expect(delivery.status, SosDeliveryStatus.idle);
      delivery.dispose();
    });
  });

  group("confirmSosAndDial", () {
    Future<void> openFlow(WidgetTester tester, VoidCallback start,
        {Future<bool> Function()? dialer}) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmSosAndDial(context,
                confirmMessage: "Only in a real emergency.",
                startDelivery: start,
                openDialer: dialer ?? () async => false),
            child: const Text("SOS"),
          ),
        ),
      ));
      await tester.tap(find.text("SOS"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets("cancelling sends nothing and dials nothing", (tester) async {
      var started = 0;
      await openFlow(tester, () => started++);
      expect(find.textContaining(kEmergencyNumber), findsWidgets);

      await tester.tap(find.text("Cancel"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(started, 0);
      expect(find.text("Call for help"), findsNothing);
    });

    testWidgets("confirming starts the alert before opening the dialer",
        (tester) async {
      final events = <String>[];
      await openFlow(tester, () => events.add("send"), dialer: () async {
        events.add("dial");
        return true;
      });

      await tester.tap(find.text("Send SOS and open dialer"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(events, ["send", "dial"]);
      expect(find.text("Call for help"), findsNothing);
    });

    testWidgets("with no dialer (e.g. a tablet) it shows the number to dial",
        (tester) async {
      var started = 0;
      await openFlow(tester, () => started++, dialer: () async => false);

      await tester.tap(find.text("Send SOS and open dialer"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(started, 1);
      expect(find.text("Call for help"), findsOneWidget);
      expect(find.text(kEmergencyNumber), findsOneWidget);
    });
  });

  testWidgets("status banner says where the alert stands", (tester) async {
    final delivery = SosDelivery(onChanged: () {});
    Future<void> show() => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SosStatusBanner(delivery: delivery))));

    await show();
    expect(find.textContaining("SOS"), findsNothing);

    await tester.runAsync(() => delivery.send(() async => false));
    await show();
    expect(find.text("SOS not sent yet — retrying"), findsOneWidget);
    expect(find.text("Retry"), findsOneWidget);

    await tester.runAsync(() => delivery.send(() async => true));
    await show();
    expect(find.text("SOS sent to FindMeTricycle admin"), findsOneWidget);
    delivery.dispose();
  });

  test("production builds dial 911", () {
    // Run without --dart-define=EMERGENCY_NUMBER.
    expect(kEmergencyNumber, "911");
    expect(kIsEmergencyTestBuild, isFalse);
  });
}
