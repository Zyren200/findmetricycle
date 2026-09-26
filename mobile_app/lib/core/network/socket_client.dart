import "dart:async";
import "package:socket_io_client/socket_io_client.dart" as io;
import "../config/app_config.dart";

class SocketClient {
  io.Socket? _socket;
  final Map<String, StreamController<dynamic>> _eventControllers = {};
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  bool get isConnected => _socket?.connected == true;

  /// Emits true on connect/reconnect, false on disconnect. Used by UI
  /// (e.g. the driver "Internet" status pill) and by controllers that need
  /// to re-sync state after a reconnect — socket.io-client already
  /// reconnects automatically, this just surfaces that as a stream.
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  void connect(String token) {
    disconnect();

    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(["websocket"])
          .disableAutoConnect()
          .setAuth({"token": token})
          .build(),
    );

    _socket!.onConnect((_) => _emitConnectionStatus(true));
    _socket!.onReconnect((_) => _emitConnectionStatus(true));
    _socket!.onDisconnect((_) => _emitConnectionStatus(false));
    _socket!.onConnectError((_) => _emitConnectionStatus(false));

    _socket!.connect();
  }

  void _emitConnectionStatus(bool connected) {
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(connected);
    }
  }

  void disconnect() {
    for (final controller in _eventControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _eventControllers.clear();

    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  Future<dynamic> emit(String event, [dynamic payload]) async {
    if (_socket == null) return null;

    final completer = Completer<dynamic>();
    _socket?.emit(event, [payload, (response) {
      if (!completer.isCompleted) {
        completer.complete(response);
      }
    }]);

    return completer.future;
  }

  Stream<dynamic> on(String event) {
    final existing = _eventControllers[event];
    if (existing != null) {
      return existing.stream;
    }

    final controller = StreamController<dynamic>.broadcast();
    _eventControllers[event] = controller;
    _socket?.on(event, (data) {
      if (!controller.isClosed) {
        controller.add(data);
      }
    });
    return controller.stream;
  }
}
