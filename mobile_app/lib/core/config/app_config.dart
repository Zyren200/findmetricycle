import "package:flutter/foundation.dart";

class AppConfig {
  static const String _defaultPort = "5000";
  static const String _webHost = "localhost";
  static const String _androidEmulatorHost = "10.0.2.2";
  static const String _apiHostOverride =
      String.fromEnvironment("API_HOST", defaultValue: "");
  static const String _apiPortOverride =
      String.fromEnvironment("API_PORT", defaultValue: _defaultPort);
  static const String _apiBaseUrlOverride =
      String.fromEnvironment("API_BASE_URL", defaultValue: "");
  static const String _socketUrlOverride =
      String.fromEnvironment("SOCKET_URL", defaultValue: "");

  static String get _defaultHost {
    if (kIsWeb) return _webHost;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidEmulatorHost;
    }
    return _webHost;
  }

  static String get _host {
    if (_apiHostOverride.isNotEmpty) return _apiHostOverride;
    return _defaultHost;
  }

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    return "http://$_host:$_apiPortOverride/api";
  }

  static String get socketUrl {
    if (_socketUrlOverride.isNotEmpty) return _socketUrlOverride;
    if (_apiBaseUrlOverride.isNotEmpty) {
      final uri = Uri.parse(_apiBaseUrlOverride);
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
      ).toString();
    }
    return "http://$_host:$_apiPortOverride";
  }

  static String get backendOrigin {
    final uri = Uri.parse(apiBaseUrl);
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }

  static String resolveAssetUrl(String path) {
    if (path.startsWith("http://") || path.startsWith("https://")) {
      return path;
    }
    if (path.startsWith("/")) {
      return "$backendOrigin$path";
    }
    return "$backendOrigin/$path";
  }

  static const double defaultBaseFare = 20.0;
  static const double defaultPerKmRate = 12.0;
  static const String openFreeMapStyleUrl =
      "https://tiles.openfreemap.org/styles/liberty";

  static const String _driverApplyUrlOverride =
      String.fromEnvironment("DRIVER_APPLY_URL", defaultValue: "");

  /// The standalone Driver Application Website — opened in the device
  /// browser from the passenger "Become a Driver" button. Defaults to the
  /// same host as the API, on the website's dev-server port.
  static String get driverApplyUrl {
    if (_driverApplyUrlOverride.isNotEmpty) return _driverApplyUrlOverride;
    return "http://$_host:5174";
  }
}
