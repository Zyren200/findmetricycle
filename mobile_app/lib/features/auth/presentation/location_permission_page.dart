import "dart:async";

import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "package:provider/provider.dart";

import "../../../core/components/sunrise.dart";
import "../../../core/state/app_preferences.dart";
import "../../../core/theme/design_tokens.dart";

/// Lets the rest of startup (push registration) wait until the location
/// question is out of the way — Android shows one permission dialog at a
/// time.
class LocationPrompt {
  LocationPrompt._();

  static Completer<void> _done = Completer<void>();

  static Future<void> get done => _done.future;

  static void complete() {
    if (!_done.isCompleted) _done.complete();
  }

  /// A new sign-in asks again (if it still has to).
  static void reset() {
    if (_done.isCompleted) _done = Completer<void>();
  }
}

/// Shows "Turn on your location" once after signing in, when the app
/// doesn't have location access yet; otherwise goes straight to [child].
class LocationGate extends StatefulWidget {
  const LocationGate({super.key, required this.child});

  final Widget child;

  @override
  State<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends State<LocationGate> {
  /// null while checking.
  bool? _ask;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = context.read<AppPreferences>();
    await prefs.ready;
    var granted = false;
    try {
      final permission = await Geolocator.checkPermission();
      granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {}
    if (!mounted) return;
    final ask = !granted && !prefs.locationPromptSeen;
    if (!ask) LocationPrompt.complete();
    setState(() => _ask = ask);
  }

  Future<void> _finish() async {
    await context.read<AppPreferences>().setLocationPromptSeen();
    LocationPrompt.complete();
    if (mounted) setState(() => _ask = false);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_ask) {
      null => const Scaffold(backgroundColor: Colors.transparent),
      true => LocationPermissionPage(onDone: _finish),
      false => widget.child,
    };
  }
}

/// "Turn on your location" — asks for permission, or "Not now".
class LocationPermissionPage extends StatefulWidget {
  const LocationPermissionPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<LocationPermissionPage> createState() => _LocationPermissionPageState();
}

class _LocationPermissionPageState extends State<LocationPermissionPage> {
  bool _asking = false;

  Future<void> _allow() async {
    setState(() => _asking = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      }
    } catch (_) {
      // The map asks again when it needs a fix.
    }
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 56, 28, 28),
          child: Column(
            children: [
              FadeRise(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            color: DesignTokens.lagoonSoft,
                            shape: BoxShape.circle),
                      ),
                      HaloRing(
                        size: 160,
                        color: DesignTokens.lagoon,
                        from: 0.85,
                        to: 1.45,
                        period: const Duration(milliseconds: 2600),
                      ),
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          color: DesignTokens.lagoon,
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: DesignTokens.shadowLagoon,
                        ),
                        child: Icon(Icons.location_on_outlined,
                            size: 52, color: DesignTokens.lagoonInk),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeRise(
                delay: const Duration(milliseconds: 100),
                child: Column(
                  children: [
                    Text("Turn on your location",
                        textAlign: TextAlign.center,
                        style: DesignTokens.display),
                    const SizedBox(height: 10),
                    Text(
                      "So riders can find your pickup point and you can see who's nearby. We use it only while you book or ride.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: DesignTokens.ink2,
                          fontSize: 15,
                          height: 23 / 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SunButton(
                label: "Allow location",
                loading: _asking,
                onPressed: _allow,
              ),
              const SizedBox(height: 10),
              SunButton(
                label: "Not now",
                tone: SunTone.ghost,
                height: 52,
                fontSize: 15,
                onPressed: _asking ? null : widget.onDone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
