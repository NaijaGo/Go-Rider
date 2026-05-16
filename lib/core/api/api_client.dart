import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/app_storage.dart';

class ApiClient {
  static String get _defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';

    return 'https://naijago-backend.onrender.com/api';
  }

  static String get socketBaseUrl {
    final baseUrl = dio.options.baseUrl;
    return baseUrl.endsWith('/api')
        ? baseUrl.substring(0, baseUrl.length - 4)
        : baseUrl;
  }

  static String get _configuredBaseUrl {
    final value = const String.fromEnvironment('API_BASE_URL');
    final baseUrl = value.isNotEmpty ? value : _defaultBaseUrl;
    return baseUrl.endsWith('/api') ? baseUrl : '$baseUrl/api';
  }

  static final Dio dio =
      Dio(
          BaseOptions(
            baseUrl: _configuredBaseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.extra['skipAuth'] == true) {
                options.headers.remove('Authorization');
                return handler.next(options);
              }

              final token = AppStorage.token;

              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }

              return handler.next(options);
            },
          ),
        );
}
