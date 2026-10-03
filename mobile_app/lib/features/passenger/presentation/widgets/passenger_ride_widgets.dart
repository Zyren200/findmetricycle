import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart" as ll;

import "../../../../core/components/index.dart";
import "../../../../core/theme/design_tokens.dart";
import "../passenger_ride_controller.dart";

// Pieces shared by the passenger home, booking steps and ride status
// screens.

const Color kPickupColor = Color(0xFF0E8C46);
const Color kDropoffColor = Color(0xFFC94530);

String? asText(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  return value.toString();
}

String formatMoney(dynamic amount) {
  final value = amount is num
      ? amount.toDouble()
      : double.tryParse(amount?.toString() ?? "") ?? 0;
  return "₱${value.toStringAsFixed(2)}";
}

String _pointLabel(ll.LatLng point) =>
    "${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}";

String pickupText(PassengerRideController ctrl,
    {String empty = "Set pickup location..."}) {
  if (ctrl.pickup == null) return empty;
  if (ctrl.pickupAddress != null) return ctrl.pickupAddress!;
  if (ctrl.isResolvingPickupAddress) return "Locating address…";
  return _pointLabel(ctrl.pickup!);
}

String dropoffText(PassengerRideController ctrl,
    {String empty = "Set destination..."}) {
  if (ctrl.dropoff == null) return empty;
  if (ctrl.dropoffAddress != null) return ctrl.dropoffAddress!;
  if (ctrl.isResolvingDropoffAddress) return "Locating address…";
  return _pointLabel(ctrl.dropoff!);
}

/// Whether the passenger has a booking that isn't finished yet.
bool hasOngoingBooking(PassengerRideController ctrl) =>
    ctrl.activeBookingId != null &&
    ctrl.bookingStatus != null &&
    kActiveBookingStatuses.contains(ctrl.bookingStatus);

/// Headline for the ride status banner / home "Active Ride" card.
String rideStatusHeadline(PassengerRideController ctrl) {
  if (ctrl.isChoosingDriver) return "Choose your rider";
  if (ctrl.isWaitingForDriverResponse) {
    return "Waiting for the rider to accept…";
  }
  return switch (ctrl.bookingStatus) {
    "searching" => "Searching for a driver...",
    "accepted" || "assigned" => "Driver accepted your ride",
    "arriving" => "Driver has arrived! Show your PIN",
    "ongoing" || "on_ride" => "Ride in progress",
    "completed" => "Completed",
    "cancelled" => "Cancelled",
    _ => bookingStatusLabel(ctrl.bookingStatus),
  };
}

/// Shown when the passenger's GPS is outside Guiuan: explains the service
/// area (and that pickups there are refused while it's enforced).
class ServiceAreaNotice extends StatelessWidget {
  const ServiceAreaNotice({super.key, required this.ctrl});

  final PassengerRideController ctrl;

  @override
  Widget build(BuildContext context) {
    if (!ctrl.isOutsideServiceArea) return const SizedBox.shrink();
    final message = ctrl.serviceAreaEnforced
        ? "You're outside Guiuan. FindMeTricycle only operates within Guiuan — choose a pickup point inside Guiuan on the map or by search."
        : "You're outside Guiuan, FindMeTricycle's service area. Bookings from here are allowed only while the service area isn't enforced (testing).";
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DesignTokens.blue.withAlpha(22),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        border: Border.all(color: DesignTokens.blue.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: DesignTokens.blue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: DesignTokens.text, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Location status for the map areas, or null when the position is known.
class LocationStatusBox extends StatelessWidget {
  const LocationStatusBox({super.key, required this.ctrl});

  final PassengerRideController ctrl;

  @override
  Widget build(BuildContext context) {
    if (ctrl.currentPosition != null) return const SizedBox.shrink();

    final String message;
    String? actionLabel;
    VoidCallback? onAction;
    var spinner = false;
    if (ctrl.locationPermissionDeniedForever) {
      message =
          "Location permission denied. Enable it in Settings to use full features.";
      actionLabel = "Settings";
      onAction = Geolocator.openAppSettings;
    } else if (ctrl.isResolvingLocation) {
      message = "Getting your location...";
      spinner = true;
    } else if (ctrl.locationServiceDisabled) {
      message = "GPS is off. Turn on Location to use full features.";
      actionLabel = "Turn on";
      onAction = () async {
        await Geolocator.openLocationSettings();
        await ctrl.refreshCurrentLocation();
      };
    } else {
      message = ctrl.locationError ?? "Getting your location...";
      spinner = ctrl.locationError == null;
      if (!spinner) {
        actionLabel = "Retry";
        onAction = ctrl.refreshCurrentLocation;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DesignTokens.warning.withAlpha(24),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        border: Border.all(color: DesignTokens.warning.withAlpha(70)),
      ),
      child: Row(
        children: [
          if (spinner)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: DesignTokens.warning),
            )
          else
            Icon(Icons.warning_amber_rounded,
                color: DesignTokens.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: DesignTokens.warning, fontSize: 12)),
          ),
          if (actionLabel != null && onAction != null)
            TextButton.icon(
              onPressed: onAction,
              icon: Icon(Icons.refresh_rounded,
                  size: 14, color: DesignTokens.warning),
              label: Text(actionLabel,
                  style: TextStyle(color: DesignTokens.warning, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

/// Bordered input-looking row that opens a picker when tapped.
class LocationField extends StatelessWidget {
  const LocationField({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.isPlaceholder,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final bool isPlaceholder;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignTokens.bg3,
      borderRadius: BorderRadius.circular(DesignTokens.radiusSm + 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm + 2),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusSm + 2),
            border: Border.all(color: DesignTokens.border2),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        isPlaceholder ? DesignTokens.muted : DesignTokens.text,
                    fontSize: 14,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// A place in a pick list (current location, saved place, search result).
class PlaceListTile extends StatelessWidget {
  const PlaceListTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: DesignTokens.text,
                          fontSize: 14,
                          fontWeight: DesignTokens.fw600)),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: DesignTokens.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Initial-letter avatar circle.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(
      {super.key, required this.name, this.size = 48, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? DesignTokens.accent;
    final initial = name.trim().isEmpty ? "?" : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: tint.withAlpha(40), shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(
          color: tint,
          fontSize: size * 0.4,
          fontWeight: DesignTokens.fw700,
        ),
      ),
    );
  }
}

/// One rider the passenger can choose.
class DriverOptionTile extends StatelessWidget {
  const DriverOptionTile({
    super.key,
    required this.driver,
    required this.isNearest,
    required this.enabled,
    required this.onTap,
  });

  final Map<String, dynamic> driver;
  final bool isNearest;
  final bool enabled;
  final void Function(int driverId) onTap;

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse(driver["id"]?.toString() ?? "");
    final name = asText(driver["full_name"]) ?? "Rider";
    final tricycle = asText(driver["tricycle_number"]) ?? "-";
    final rating = double.tryParse(driver["rating"]?.toString() ?? "") ?? 0;
    final rides = int.tryParse(driver["total_rides"]?.toString() ?? "") ?? 0;
    final distance =
        double.tryParse(driver["distanceToPickupKm"]?.toString() ?? "");

    return Material(
      color: DesignTokens.bg2,
      borderRadius: BorderRadius.circular(DesignTokens.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        onTap: enabled && id != null ? () => onTap(id) : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radius),
            border: Border.all(
              color: isNearest ? DesignTokens.accent : DesignTokens.border,
            ),
          ),
          child: Row(
            children: [
              InitialAvatar(name: name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: DesignTokens.text,
                                  fontWeight: DesignTokens.fw700)),
                        ),
                        if (isNearest) ...[
                          const SizedBox(width: 6),
                          const AppBadge(
                              label: "Nearest", style: BadgeStyle.greenStyle),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        "Tricycle $tricycle",
                        if (distance != null)
                          distance < 1
                              ? "${(distance * 1000).round()} m away"
                              : "${distance.toStringAsFixed(1)} km away",
                        "$rides rides",
                      ].join(" · "),
                      style: TextStyle(color: DesignTokens.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
              const SizedBox(width: 2),
              Text(rating.toStringAsFixed(1),
                  style: TextStyle(color: DesignTokens.text, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big, readable PIN for the passenger to show/read to the rider.
Future<void> showPickupPinDialog(BuildContext context, String pin) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: DesignTokens.bg2,
      title: Text(
        "Your Pickup PIN",
        style: TextStyle(color: DesignTokens.text, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Show this PIN to your driver to start the ride.",
            textAlign: TextAlign.center,
            style: TextStyle(color: DesignTokens.muted),
          ),
          const SizedBox(height: 16),
          Text(
            pin,
            style: TextStyle(
              color: DesignTokens.accent,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 14,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text("OK", style: TextStyle(color: DesignTokens.accent)),
        ),
      ],
    ),
  );
}

/// Confirms, then sends an SOS alert with the passenger's location.
Future<void> confirmAndSendSos(
    BuildContext context, PassengerRideController ctrl) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Send SOS Alert?"),
      content: const Text(
        "This will immediately notify the admin team with your current location. "
        "Only use this in a real emergency.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text("Send SOS"),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final success = await ctrl.sendSos();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(success
          ? (ctrl.sosMessage ?? "SOS alert sent.")
          : (ctrl.error ?? "Failed to send SOS alert.")),
      backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
    ),
  );
}
