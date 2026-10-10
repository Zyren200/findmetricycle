import "dart:async";

import "package:flutter/widgets.dart";

enum SosDeliveryStatus {
  /// No SOS in progress (or its result was dismissed).
  idle,
  sending,

  /// The admin team has the alert.
  sent,

  /// The last attempt failed (usually no internet); retrying.
  pending,
}

/// Gets an SOS alert to the server, however long the network takes: after
/// a failed attempt it tries again every [retryEvery] and whenever the app
/// comes back to the foreground (e.g. from the dialer), until one succeeds.
/// Never blocks the caller — the dialer opens while this is still working.
class SosDelivery with WidgetsBindingObserver {
  SosDelivery({
    required this.onChanged,
    this.retryEvery = const Duration(seconds: 20),
  });

  final VoidCallback onChanged;
  final Duration retryEvery;

  SosDeliveryStatus status = SosDeliveryStatus.idle;
  Future<bool> Function()? _attempt;
  Timer? _timer;
  bool _observing = false;
  bool _disposed = false;

  /// Starts delivering an alert; [attempt] sends it once and says whether
  /// it went through. A newer alert replaces one still pending.
  Future<bool> send(Future<bool> Function() attempt) {
    _attempt = attempt;
    return _run();
  }

  /// One more try now, if an alert is still waiting to go out.
  Future<bool> retry() async {
    if (_attempt == null || status == SosDeliveryStatus.sending) return false;
    return _run();
  }

  /// Hides a delivered alert's status. A pending one keeps retrying.
  void dismiss() {
    if (status != SosDeliveryStatus.sent) return;
    status = SosDeliveryStatus.idle;
    onChanged();
  }

  Future<bool> _run() async {
    final attempt = _attempt!;
    status = SosDeliveryStatus.sending;
    onChanged();

    var ok = false;
    try {
      ok = await attempt();
    } catch (_) {
      ok = false;
    }
    if (_disposed) return ok;
    // A newer alert started meanwhile; its own run reports.
    if (!identical(attempt, _attempt)) return ok;

    if (ok) {
      _attempt = null;
      _stopRetrying();
      status = SosDeliveryStatus.sent;
    } else {
      _startRetrying();
      status = SosDeliveryStatus.pending;
    }
    onChanged();
    return ok;
  }

  void _startRetrying() {
    _timer ??= Timer.periodic(retryEvery, (_) => retry());
    if (!_observing) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _observing = true;
      } catch (_) {
        // No binding (plain unit tests): the timer still retries.
      }
    }
  }

  void _stopRetrying() {
    _timer?.cancel();
    _timer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) retry();
  }

  void dispose() {
    _disposed = true;
    _stopRetrying();
  }
}
