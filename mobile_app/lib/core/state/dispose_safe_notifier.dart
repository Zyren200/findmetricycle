import "package:flutter/foundation.dart";

/// For controllers torn down while work they started is still in flight —
/// a GPS fix or API call that finishes after the user switched Passenger ↔
/// Driver mode or logged out. A late notifyListeners() after dispose() is
/// ignored instead of throwing "used after being disposed".
mixin DisposeSafeNotifier on ChangeNotifier {
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
