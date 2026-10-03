import "dart:async";

import "package:flutter/foundation.dart";

import "../../../core/network/api_client.dart";
import "../../../core/network/socket_client.dart";
import "../../../core/state/dispose_safe_notifier.dart";

/// The signed-in user's notifications for one app mode ("passenger" or
/// "driver"): the list, the unread count for the 🔔 badge, and live
/// updates from the socket.
class NotificationsController extends ChangeNotifier with DisposeSafeNotifier {
  NotificationsController(this._api, this._socket, {required this.role}) {
    _liveSub = _socket.on("notification:created").listen(_onLive);
  }

  final ApiClient _api;
  final SocketClient _socket;

  /// "passenger" or "driver" — also the API path prefix.
  final String role;

  List<Map<String, dynamic>> items = [];
  int unread = 0;
  bool isLoading = false;
  String? error;
  StreamSubscription? _liveSub;

  String get _base => "/$role/notifications";

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final response = await _api.get(_base);
      if (response["success"] != true) {
        throw Exception(response["message"]?.toString());
      }
      items = (response["data"] is List ? response["data"] as List : const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      unread = int.tryParse(response["meta"]?["unread"]?.toString() ?? "") ??
          items.where((n) => !isRead(n)).length;
    } catch (_) {
      error = "Hindi ma-load ang notifications. Subukan ulit.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Marks one notification read — when it's opened, like an email.
  Future<void> markRead(Map<String, dynamic> notification) async {
    if (isRead(notification)) return;
    final id = notification["id"];
    items = [
      for (final n in items) n["id"] == id ? {...n, "is_read": 1} : n
    ];
    unread = unread > 0 ? unread - 1 : 0;
    notifyListeners();
    try {
      await _api.post("$_base/read", data: {
        "ids": [id]
      });
    } catch (_) {
      // The next load re-syncs from the server.
    }
  }

  /// Marks everything as read (the "All read" button).
  Future<void> markAllRead() async {
    if (unread == 0 && items.every(isRead)) return;
    items = [
      for (final n in items) {...n, "is_read": 1}
    ];
    unread = 0;
    notifyListeners();
    try {
      await _api.post("$_base/read", data: const {});
    } catch (_) {
      // The next load re-syncs from the server.
    }
  }

  /// Announcements are one shared row for everyone, so they have no
  /// per-user read state (and aren't in the unread count): never unread.
  static bool isRead(Map<String, dynamic> n) =>
      n["type"] == "announcement" ||
      n["is_read"] == 1 ||
      n["is_read"] == true ||
      n["isRead"] == true;

  void _onLive(dynamic event) {
    if (event is! Map) return;
    final n = Map<String, dynamic>.from(event);
    // One account can be passenger and driver: keep this mode's only.
    final target = n["recipientRole"]?.toString();
    if (target != null && target != role && target != "everyone") return;
    final id = n["id"];
    if (id == null || items.any((item) => item["id"] == id)) return;
    items = [
      {
        "id": id,
        "type": n["type"],
        "title": n["title"],
        "body": n["body"],
        "is_read": 0,
        "created_at": n["createdAt"] ?? DateTime.now().toIso8601String(),
        "metadata": n["metadata"],
      },
      ...items,
    ];
    if (n["type"] != "announcement") unread += 1;
    notifyListeners();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }
}
