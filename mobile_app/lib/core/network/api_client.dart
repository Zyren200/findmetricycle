import "package:dio/dio.dart";
import "../config/app_config.dart";

/// Called when a request comes back 401 (access token expired/invalid).
/// Should attempt a token refresh and return the new access token, or null
/// if refresh isn't possible (no session, refresh token also expired, etc).
typedef UnauthorizedHandler = Future<String?> Function();

class ApiClient {
  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (_) => true, // let us handle errors without throwing
      ),
    );
    _dio.interceptors.add(QueuedInterceptorsWrapper(onResponse: _handleResponse));
  }

  late final Dio _dio;
  UnauthorizedHandler? onUnauthorized;

  /// The access token dies after 15 minutes (see backend
  /// JWT_ACCESS_EXPIRES_IN); without this, every request after that just
  /// surfaces the backend's raw "Invalid or expired token." error instead
  /// of silently refreshing the session the way a logged-in user expects.
  Future<void> _handleResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final isAuthEndpoint = response.requestOptions.path.contains("/auth/");
    final alreadyRetried = response.requestOptions.extra["retriedAfterRefresh"] == true;

    if (response.statusCode != 401 || isAuthEndpoint || alreadyRetried || onUnauthorized == null) {
      handler.next(response);
      return;
    }

    final newToken = await onUnauthorized!.call();
    if (newToken == null || newToken.isEmpty) {
      handler.next(response);
      return;
    }

    try {
      final retryOptions = response.requestOptions
        ..headers["Authorization"] = "Bearer $newToken"
        ..extra["retriedAfterRefresh"] = true;
      final retryResponse = await _dio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      handler.next(response);
    }
  }

  void setToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove("Authorization");
      return;
    }
    _dio.options.headers["Authorization"] = "Bearer $token";
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(path,
        data: data, queryParameters: queryParameters);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> postForm(
    String path, {
    required FormData data,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(path, data: data);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> patchForm(
    String path, {
    required FormData data,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      path,
      data: data,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(path, data: data);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(path,
        queryParameters: queryParameters);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      path,
      data: data,
    );
    return response.data ?? <String, dynamic>{};
  }
}
