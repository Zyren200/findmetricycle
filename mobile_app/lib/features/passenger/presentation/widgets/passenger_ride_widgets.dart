import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../../core/components/index.dart";
import "../../../../core/safety/sos_flow.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../../core/utils/ride_format.dart";
import "../../../shared/presentation/report_issue_sheet.dart";
import "../passenger_ride_controller.dart";

// Pieces shared by the passenger home, booking and ride status screens.

/// Pickup is lagoon, the drop-off sunset orange (Sunrise map colours).
const Color kPickupColor = Color(0xFF1FC8B4);
const Color kDropoffColor = Color(0xFFFF7A1A);

String? asText(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  return value.toString();
}

String formatMoney(dynamic amount) {
  final value = amount is num
      ? amount.toDouble()
      : double.tryParse(amount?.toString() ?? "") ?? 0;
  return peso(value);
}

/// "₱25" for whole amounts, "₱25.50" otherwise — the compact fare on
/// chips and the ride sheet.
String shortMoney(dynamic amount) {
  final value = amount is num
      ? amount.toDouble()
      : double.tryParse(amount?.toString() ?? "") ?? 0;
  return value == value.roundToDouble()
      ? "₱${groupThousands(value.toStringAsFixed(0))}"
      : peso(value);
}

/// The address, or — when the place couldn't be named — a pinned spot,
/// never a string of coordinates.
String pickupText(PassengerRideController ctrl,
    {String empty = "Set pickup location..."}) {
  if (ctrl.pickup == null) return empty;
  if (ctrl.pickupAddress != null) return placeLabel(ctrl.pickupAddress);
  if (ctrl.isResolvingPickupAddress) return "Locating address…";
  return kPinnedPlaceLabel;
}

String dropoffText(PassengerRideController ctrl,
    {String empty = "Set destination..."}) {
  if (ctrl.dropoff == null) return empty;
  if (ctrl.dropoffAddress != null) return placeLabel(ctrl.dropoffAddress);
  if (ctrl.isResolvingDropoffAddress) return "Locating address…";
  return kPinnedPlaceLabel;
}

/// The first part of a place label ("Guiuan Public Market" of "Guiuan
/// Public Market, Brgy. …").
String shortPlace(String label) => splitPlaceLabel(label).title;

/// Whether the passenger has a booking that isn't finished yet.
bool hasOngoingBooking(PassengerRideController ctrl) =>
    ctrl.activeBookingId != null &&
    ctrl.bookingStatus != null &&
    kActiveBookingStatuses.contains(ctrl.bookingStatus);

/// The rider's first name ("Ramon" of "Ramon Dela Cruz").
String firstName(String? name, {String fallback = "Your rider"}) {
  final first = name?.trim().split(RegExp(r"\s+")).first ?? "";
  return first.isEmpty ? fallback : first;
}

/// Headline for the ride status pill / home "Active ride" card.
String rideStatusHeadline(PassengerRideController ctrl) {
  if (ctrl.isChoosingDriver) return "Choose your rider";
  if (ctrl.isWaitingForDriverResponse) {
    return "Waiting for ${firstName(ctrl.driverName, fallback: "the rider")} to accept…";
  }
  final rider = firstName(ctrl.driverName);
  return switch (ctrl.bookingStatus) {
    "searching" => "Searching for a rider…",
    "accepted" || "assigned" => "$rider is on the way",
    "arriving" => "$rider has arrived",
    "ongoing" ||
    "on_ride" =>
      "Heading to ${shortPlace(dropoffText(ctrl, empty: "your drop-off"))}",
    "completed" => "Ride completed",
    "cancelled" => "Ride cancelled",
    _ => bookingStatusLabel(ctrl.bookingStatus),
  };
}

/// Second line under the headline.
String rideStatusDetail(PassengerRideController ctrl) {
  final km = ctrl.driverDistanceToPickupKm;
  String away(double d) => d < 1
      ? "${(d * 1000).round()} m away"
      : "${d.toStringAsFixed(1)} km away";
  return switch (ctrl.bookingStatus) {
    "accepted" ||
    "assigned" =>
      km == null ? "Heading to your pickup" : "Arriving · ${away(km)}",
    "arriving" => "Meet your rider at the pickup point",
    "ongoing" || "on_ride" => "Enjoy the ride · pay in cash at drop-off",
    _ => ctrl.rideNotice ?? "",
  };
}

/// The rider's phone number from the booking, if the server sent it.
String? driverPhone(PassengerRideController ctrl) =>
    asText(ctrl.bookingData?["driver_phone"]) ??
    asText(ctrl.driverInfo?["phone"]) ??
    asText(ctrl.driverInfo?["driver_phone"]);

Future<void> callNumber(BuildContext context, String? number) async {
  if (number == null) return;
  final ok = await launchUrl(Uri(scheme: "tel", path: number));
  if (!ok && context.mounted) {
    showSunToast(context, "Couldn't open the dialer. Call $number.");
  }
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
    return _Notice(
      icon: Icons.info_outline_rounded,
      background: DesignTokens.lagoonSoft,
      foreground: DesignTokens.lagoonText,
      message: message,
    );
  }
}

/// Location status (GPS off, permission denied, locating), or nothing once
/// the position is known.
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

    return _Notice(
      icon: Icons.location_off_rounded,
      spinner: spinner,
      background: DesignTokens.primarySoft,
      foreground: DesignTokens.primaryText,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.message,
    this.spinner = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String message;
  final bool spinner;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (spinner)
            SizedBox(
              width: 16,
              height: 16,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: foreground),
            )
          else
            Icon(icon, color: foreground, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: DesignTokens.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!,
                  style: TextStyle(color: foreground, fontSize: 13)),
            ),
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              IconTile(
                icon: icon,
                size: 40,
                radius: 12,
                iconSize: 19,
                background: iconColor.withAlpha(DesignTokens.isDark ? 46 : 30),
                foreground: iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: DesignTokens.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    if (subtitle != null)
                      Text(subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: DesignTokens.ink2,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Initials avatar (kept for older call sites).
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(
      {super.key, required this.name, this.size = 48, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      ToneAvatar(name: name, size: size, tone: toneFor(name));
}

/// One rider the passenger can choose: tap to select (orange outline and
/// a check), then "Request …".
class RiderOptionTile extends StatelessWidget {
  const RiderOptionTile({
    super.key,
    required this.driver,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.isNearest = false,
  });

  final Map<String, dynamic> driver;
  final bool selected;
  final bool enabled;
  final bool isNearest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = asText(driver["full_name"]) ?? "Rider";
    final tricycle = asText(driver["tricycle_number"]);
    final rating = double.tryParse(driver["rating"]?.toString() ?? "");
    final distance =
        double.tryParse(driver["distanceToPickupKm"]?.toString() ?? "");
    final km = distance == null
        ? null
        : distance < 1
            ? "${(distance * 1000).round()} m"
            : "${distance.toStringAsFixed(1)} km";

    // ".rider": an ember-tinted card with an ember ring when chosen.
    final base =
        DesignTokens.isDark ? const Color(0x7303040E) : const Color(0xC7FFFFFF);
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: enabled ? onTap : null,
        child: OuterShadow(
          radius: 18,
          shadows: selected
              ? [
                  BoxShadow(
                      color: DesignTokens.glowEmber,
                      blurRadius: 26,
                      spreadRadius: -14,
                      offset: const Offset(0, 12))
                ]
              : null,
          child: AnimatedContainer(
            duration: DesignTokens.quick,
            curve: DesignTokens.easeOut,
            padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
            decoration: BoxDecoration(
              color: selected
                  ? Color.alphaBlend(
                      DesignTokens.ember.withValues(alpha: .11), base)
                  : DesignTokens.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                width: selected ? 1.5 : 1,
                color: selected ? DesignTokens.ember : DesignTokens.line,
              ),
            ),
            child: Row(
              children: [
                ToneAvatar(
                    name: name,
                    size: 42,
                    circle: true,
                    tone: toneFor(driver["id"] ?? name)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: DesignTokens.ink,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (isNearest) ...[
                            const SizedBox(width: 6),
                            const StatusChip("Nearest", tone: ChipTone.ok),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (tricycle != null)
                            Flexible(
                              child: Text("Tricycle $tricycle",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: DesignTokens.ink2,
                                      fontSize: 12.5)),
                            ),
                          if (rating != null) ...[
                            Text(tricycle != null ? " · " : "",
                                style: TextStyle(
                                    color: DesignTokens.ink2,
                                    fontSize: 12.5)),
                            Icon(Icons.star_rounded,
                                size: 13, color: DesignTokens.amber),
                            const SizedBox(width: 2),
                            Text(rating.toStringAsFixed(1),
                                style: TextStyle(
                                    color: DesignTokens.ink2,
                                    fontSize: 12.5)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (km != null)
                  Text(km,
                      style: DesignTokens.mono.copyWith(
                          color: DesignTokens.ink1, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ★ 4.9 pill.
class RatingPill extends StatelessWidget {
  const RatingPill({super.key, required this.rating});

  final double? rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: DesignTokens.surface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 14, color: DesignTokens.star),
          const SizedBox(width: 3),
          Text(
            rating == null || rating == 0 ? "New" : rating!.toStringAsFixed(1),
            style: TextStyle(
              color: DesignTokens.ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: DesignTokens.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Big, readable PIN for the passenger to show / read to the rider.
Future<void> showPickupPinDialog(BuildContext context, String pin) {
  return showSunSheet<void>(
    context,
    builder: (dialogContext) => SunSheetCard(
      title: "Your pickup PIN",
      message: "Your rider has arrived. Give this PIN to your rider before "
          "the trip starts.",
      icon: Icons.pin_rounded,
      iconBg: DesignTokens.lagoonSoft,
      iconFg: DesignTokens.lagoonText,
      content: [
        DigitBoxes(value: pin, length: pin.length, readOnly: true, height: 64),
      ],
      actions: [
        SunButton(
          label: "Got it",
          tone: SunTone.ink,
          height: 52,
          onPressed: () => Navigator.pop(dialogContext),
        ),
      ],
    ),
  );
}

/// "Report a Problem": the passenger picks a topic and describes it; the
/// report goes to the admin, tied to [bookingId] when it's about a ride.
Future<void> reportPassengerProblem(
  BuildContext context,
  PassengerRideController ctrl, {
  int? bookingId,
}) async {
  final report = await showReportIssueSheet(
    context,
    categories: kPassengerReportCategories,
    about: bookingId == null ? null : "About ride #$bookingId.",
  );
  if (report == null || !context.mounted) return;

  final failure = await ctrl.reportIssue(
    category: report.category,
    description: report.description,
    bookingId: bookingId,
  );
  if (!context.mounted) return;
  showSunToast(context, failure ?? "Report sent. The admin will review it.");
}

/// Confirms, then sends an SOS alert with the passenger's location and
/// opens the dialer with the emergency number; [SosStatusBanner] shows how
/// the alert is doing.
Future<void> confirmAndSendSos(
    BuildContext context, PassengerRideController ctrl) {
  return confirmSosAndDial(
    context,
    confirmMessage:
        "We'll alert the FindMeTricycle admin with your live location and ride.",
    startDelivery: ctrl.startSos,
    delivery: ctrl.sosDelivery,
    updates: ctrl,
  );
}
