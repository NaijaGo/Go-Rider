import 'package:dio/dio.dart';

String apiMessage(Object error, [String fallback = 'Request failed']) {
  if (error is DioException) {
    if (error.type == DioExceptionType.connectionError) {
      return 'No internet connection or backend host is unreachable. Please check your network and try again.';
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'The server is taking too long to respond. Please try again.';
    }

    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    if (error.message != null && error.message!.isNotEmpty) {
      final lowerMessage = error.message!.toLowerCase();
      if (lowerMessage.contains('failed host lookup') ||
          lowerMessage.contains('socketexception') ||
          lowerMessage.contains('unknownhost')) {
        return 'No internet connection or backend host is unreachable. Please check your network and try again.';
      }
      return error.message!;
    }
  }

  return fallback;
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  return <String, dynamic>{};
}

List<dynamic> asList(dynamic value) {
  if (value is List) return value;
  return const [];
}

double asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

String asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}
