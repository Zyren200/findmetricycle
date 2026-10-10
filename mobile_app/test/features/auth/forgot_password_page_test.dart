import "package:findme_tricycle_mobile/core/components/index.dart";
import "package:findme_tricycle_mobile/core/network/api_client.dart";
import "package:findme_tricycle_mobile/features/auth/presentation/forgot_password_page.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";

/// Answers each forgot-password endpoint from [replies] and records calls.
class FakeApi extends ApiClient {
  final List<String> posted = [];
  final List<Map<String, dynamic>?> postedData = [];
  final Map<String, Map<String, dynamic>> replies = {};

  @override
  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? data,
      Map<String, dynamic>? queryParameters}) async {
    posted.add(path);
    postedData.add(data);
    return replies[path] ?? {"success": true};
  }
}

const _request = "/auth/v2/forgot-password/request";
const _verify = "/auth/v2/forgot-password/verify";
const _reset = "/auth/v2/forgot-password/reset";

void main() {
  late FakeApi api;
  // What the page popped with; "-" until it pops.
  late String? result;

  setUp(() {
    api = FakeApi();
    result = "-";
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      Provider<ApiClient>.value(
        value: api,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordPage(),
                    ),
                  );
                },
                child: const Text("open"),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.descendant(
      of: find.widgetWithText(SunField, label),
      matching: find.byType(TextField));

  // Tapped first, like a user would: moving focus from one obscured field
  // to the next with enterText alone doesn't reach the new field in tests.
  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.tap(field(label));
    await tester.pump();
    await tester.enterText(field(label), text);
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    await tester.enterText(
        find.descendant(
            of: find.byType(OtpInput), matching: find.byType(TextField)),
        code);
    await tester.pumpAndSettle();
  }

  Future<void> sendCode(WidgetTester tester) async {
    await tester.enterText(field("Email address"), "juan@example.com");
    await tester.tap(find.text("Send code"));
    await tester.pumpAndSettle();
  }

  testWidgets("email, then the code is verified, then the new password",
      (tester) async {
    await open(tester);
    expect(find.text("Forgot your password?"), findsOneWidget);
    // No password fields until the code is verified.
    expect(find.widgetWithText(SunField, "New password"), findsNothing);

    await sendCode(tester);
    expect(api.posted, [_request]);
    expect(find.text("Enter the code"), findsOneWidget);
    expect(find.widgetWithText(SunField, "New password"), findsNothing);

    await enterCode(tester, "123456");
    expect(api.posted, [_request, _verify]);
    expect(api.postedData.last,
        {"email": "juan@example.com", "code": "123456"});
    expect(find.text("Set a new password"), findsOneWidget);

    await type(tester, "New password", "newpassword1");
    await type(tester, "Confirm new password", "newpassword1");
    await tester.ensureVisible(find.text("Save new password"));
    await tester.tap(find.text("Save new password"));
    await tester.pumpAndSettle();

    expect(api.posted.last, _reset);
    expect(api.postedData.last, {
      "email": "juan@example.com",
      "code": "123456",
      "newPassword": "newpassword1",
    });
    expect(result, "juan@example.com");
  });

  testWidgets("a wrong code stays on the code step", (tester) async {
    api.replies[_verify] = {
      "success": false,
      "message": "Invalid or expired code",
    };
    await open(tester);
    await sendCode(tester);

    await enterCode(tester, "000000");

    expect(find.text("Enter the code"), findsOneWidget);
    expect(
        find.text(
            "The code is invalid or expired. Check it, or request a new one."),
        findsOneWidget);
    expect(find.text("Set a new password"), findsNothing);
    expect(api.posted, isNot(contains(_reset)));
  });

  testWidgets("an unregistered email is shown under the field",
      (tester) async {
    api.replies[_request] = {
      "success": false,
      "message": "This email is not registered.",
      "details": {"field": "email"},
    };
    await open(tester);
    await sendCode(tester);

    expect(find.text("This email is not registered."), findsOneWidget);
    expect(find.text("Forgot your password?"), findsOneWidget);
  });

  testWidgets("mismatched passwords are not sent", (tester) async {
    await open(tester);
    await sendCode(tester);
    await enterCode(tester, "123456");

    await type(tester, "New password", "newpassword1");
    await type(tester, "Confirm new password", "newpassword2");
    await tester.ensureVisible(find.text("Save new password"));
    await tester.tap(find.text("Save new password"));
    await tester.pumpAndSettle();

    expect(find.text("Passwords do not match."), findsOneWidget);
    expect(api.posted, isNot(contains(_reset)));
    expect(result, "-");
  });

  testWidgets("a code that expired after verifying starts over",
      (tester) async {
    api.replies[_reset] = {
      "success": false,
      "message": "Invalid or expired code",
    };
    await open(tester);
    await sendCode(tester);
    await enterCode(tester, "123456");

    await type(tester, "New password", "newpassword1");
    await type(tester, "Confirm new password", "newpassword1");
    await tester.ensureVisible(find.text("Save new password"));
    await tester.tap(find.text("Save new password"));
    await tester.pumpAndSettle();

    expect(find.text("Forgot your password?"), findsOneWidget);
    expect(find.text("Your code expired. Send a new one to continue."),
        findsOneWidget);
    expect(result, "-");
  });
}
