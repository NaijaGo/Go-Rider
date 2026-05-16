import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../api/api_client.dart';
import '../storage/app_storage.dart';

class SocketService {
  factory SocketService() => _instance;

  SocketService._internal();

  static final SocketService _instance = SocketService._internal();

  io.Socket? _socket;
  DateTime? _lastConnectAttempt;
  DateTime? _lastErrorLogAt;

  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    final token = AppStorage.token;
    if (token == null || token.isEmpty) return;

    final now = DateTime.now();
    final lastAttempt = _lastConnectAttempt;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(seconds: 15)) {
      return;
    }
    _lastConnectAttempt = now;

    if (_socket != null) {
      if (!isConnected) _socket!.connect();
      return;
    }

    _socket = io.io(ApiClient.socketBaseUrl, <String, dynamic>{
      'transports': ['websocket', 'polling'],
      'autoConnect': false,
      'auth': {'token': token},
      'forceNew': false,
      'timeout': 10000,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 5000,
      'reconnectionDelayMax': 30000,
    });

    _socket!
      ..onConnect((_) => debugPrint('Rider socket connected'))
      ..onDisconnect((_) => debugPrint('Rider socket disconnected'))
      ..onConnectError(_logConnectError)
      ..connect();
  }

  void on(String event, void Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void emit(String event, dynamic data) {
    connect();
    _socket?.emit(event, data);
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _lastConnectAttempt = null;
    _lastErrorLogAt = null;
  }

  void _logConnectError(dynamic error) {
    final now = DateTime.now();
    final lastLog = _lastErrorLogAt;
    if (lastLog != null &&
        now.difference(lastLog) < const Duration(seconds: 30)) {
      return;
    }
    _lastErrorLogAt = now;
    debugPrint('Rider socket error: $error');
  }
}
