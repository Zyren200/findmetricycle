import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../shared/state/notifications_controller.dart";
import "passenger_profile_controller.dart";
import "passenger_ride_controller.dart";

/// Pushes a full-screen passenger page (booking steps, ride status, ...).
///
/// A pushed route isn't a descendant of PassengerShellPage's providers, so
/// the shell-scoped controllers are handed over by value.
Future<T?> pushPassengerPage<T>(
  BuildContext context,
  Widget page, {
  bool replace = false,
}) {
  final route = MaterialPageRoute<T>(
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
            value: context.read<PassengerRideController>()),
        ChangeNotifierProvider.value(
            value: context.read<PassengerProfileController>()),
        ChangeNotifierProvider.value(
            value: context.read<NotificationsController>()),
        ChangeNotifierProvider.value(value: context.read<ValueNotifier<int>>()),
      ],
      child: page,
    ),
  );
  final navigator = Navigator.of(context);
  return replace ? navigator.pushReplacement(route) : navigator.push(route);
}
