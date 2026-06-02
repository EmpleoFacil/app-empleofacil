import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import 'api_service.dart';

class MessageRealtimeService {
  final ApiService _api;
  io.Socket? _socket;
  String? _lastToken;

  final _messageCreatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageRespondedController =
      StreamController<Map<String, dynamic>>.broadcast();

  MessageRealtimeService(this._api);

  Stream<Map<String, dynamic>> get messageCreated =>
      _messageCreatedController.stream;
  Stream<Map<String, dynamic>> get messageUpdated =>
      _messageUpdatedController.stream;
  Stream<Map<String, dynamic>> get messageResponded =>
      _messageRespondedController.stream;

  void connect() {
    final token = _api.accessToken;
    if (token == null || token.isEmpty) return;

    final currentSocket = _socket;
    if (currentSocket != null &&
        currentSocket.connected &&
        _lastToken == token) {
      return;
    }

    if (currentSocket != null) {
      disconnect();
    }

    final socket = io.io(
      '${ApiConfig.socketUrl}/messages',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    socket.on('messages:created', _emitCreated);
    socket.on('messages:updated', _emitUpdated);
    socket.on('messages:responded', _emitResponded);
    socket.connect();
    _socket = socket;
    _lastToken = token;
  }

  void subscribeToMessage(String messageId) {
    connect();
    _socket?.emit('messages:subscribe', {'messageId': messageId});
  }

  void unsubscribeFromMessage(String messageId) {
    _socket?.emit('messages:unsubscribe', {'messageId': messageId});
  }

  void disconnect() {
    final socket = _socket;
    if (socket != null) {
      socket.off('messages:created', _emitCreated);
      socket.off('messages:updated', _emitUpdated);
      socket.off('messages:responded', _emitResponded);
      socket.disconnect();
      socket.dispose();
    }
    _socket = null;
    _lastToken = null;
  }

  void dispose() {
    disconnect();
    _messageCreatedController.close();
    _messageUpdatedController.close();
    _messageRespondedController.close();
  }

  void _emitCreated(dynamic data) {
    final payload = _asMap(data);
    if (payload != null) _messageCreatedController.add(payload);
  }

  void _emitUpdated(dynamic data) {
    final payload = _asMap(data);
    if (payload != null) _messageUpdatedController.add(payload);
  }

  void _emitResponded(dynamic data) {
    final payload = _asMap(data);
    if (payload != null) _messageRespondedController.add(payload);
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}
