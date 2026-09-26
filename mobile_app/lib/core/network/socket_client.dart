import "dart:async";
import "package:socket_io_client/socket_io_client.dart" as io;
import "../config/app_config.dart";

class SocketClient {
  io.Socket? _socket;

  // One broadcast stream per event name, kept for the lifetime of the app.
  // Controllers subscribe once (`_sub ??= on(...).listen(...)`), so these
  // must survive reconnects — `connect()` runs again on every token
  // refresh, and closing the streams there silently killed every listener
  // (e.g. riders stopped receiving ride requests after ~15 minutes).
  final Map<String, StreamController<dynamic>> _eventControllers = {};
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  static const Duration _ackTimeout = Duration(seconds: 8);

  bool get isConnected => _socket?.connected == true;

  /// Emits true on connect/reconnect, false on disconnect. Used by UI
  /// (e.g. the driver "Internet" status pill) and by controllers that need
  /// to re-sync state after a reconnect — socket.io-client already
  /// reconnects automatically, this just surfaces that as a stream.
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  void connect(String token) {
    _closeSocket();

    final socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(["websocket"])
          .disableAutoConnect()
          .enableForceNew()
          .setAuth({"token": token})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) => _emitConnectionStatus(true));
    socket.onReconnect((_) => _emitConnectionStatus(true));
    socket.onDisconnect((_) => _emitConnectionStatus(false));
    socket.onConnectError((_) => _emitConnectionStatus(false));

    // Re-attach every event already being listened to onto the new socket.
    for (final event in _eventControllers.keys) {
      _attach(socket, event);
    }

    socket.connect();
  }

  void _attach(io.Socket socket, String event) {
    socket.on(event, (data) {
      final controller = _eventControllers[event];
      if (controller != null && !controller.isClosed) {
        controller.add(data);
      }
    });
  }

  void _emitConnectionStatus(bool connected) {
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(connected);
    }
  }

  void _closeSocket() {
    _socket?.dispose();
    _socket = null;
  }

  /// Drops the connection (logout). Listeners stay registered so they keep
  /// working after the next [connect].
  void disconnect() {
    _closeSocket();
    _emitConnectionStatus(false);
  }

  /// Sends [event] and waits for the server's acknowledgement. Returns null
  /// if there is no socket or the server doesn't answer in time, so callers
  /// can fall back to the equivalent HTTP endpoint.
  Future<dynamic> emit(String event, [dynamic payload]) async {
    final socket = _socket;
    if (socket == null || !socket.connected) return null;

    final completer = Completer<dynamic>();
    socket.emitWithAck(
      event,
      payload,
      ack: (response) {
        if (!completer.isCompleted) completer.complete(response);
      },
    );

    return completer.future.timeout(_ackTimeout, onTimeout: () => null);
  }

  Stream<dynamic> on(String event) {
    final existing = _eventControllers[event];
    if (existing != null) {
      return existing.stream;
    }

    final controller = StreamController<dynamic>.broadcast();
    _eventControllers[event] = controller;
    final socket = _socket;
    if (socket != null) _attach(socket, event);
    return controller.stream;
  }
}
