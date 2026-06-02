import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import 'api_service.dart';

class MessageRealtimeService {
  final ApiService _api;
  io.Socket? _socket;
  String? _lastToken;
  int _unreadCount = 0;
  Future<void>? _refreshUnreadCountRequest;
  DateTime? _lastUnreadCountSyncAt;

  final _messageCreatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageRespondedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();

  MessageRealtimeService(this._api);

  Stream<Map<String, dynamic>> get messageCreated =>
      _messageCreatedController.stream;
  Stream<Map<String, dynamic>> get messageUpdated =>
      _messageUpdatedController.stream;
  Stream<Map<String, dynamic>> get messageResponded =>
      _messageRespondedController.stream;
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  int get unreadCount => _unreadCount;

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
    unawaited(refreshUnreadCount());
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
    _refreshUnreadCountRequest = null;
    _lastUnreadCountSyncAt = null;
    _setUnreadCount(0);
  }

  void dispose() {
    disconnect();
    _messageCreatedController.close();
    _messageUpdatedController.close();
    _messageRespondedController.close();
    _unreadCountController.close();
  }

  void _emitCreated(dynamic data) {
    final payload = _asMap(data);
    if (payload != null) {
      _bumpUnreadCount(1);
      _messageCreatedController.add(payload);
    }
  }

  void _emitUpdated(dynamic data) {
    final payload = _asMap(data);
    if (payload != null) {
      final status = payload['status'] as String?;
      if (status == 'read' || status == 'responded') {
        _bumpUnreadCount(-1);
      } else {
        unawaited(refreshUnreadCount(force: true));
      }
      _messageUpdatedController.add(payload);
    }
  }

  void _emitResponded(dynamic data) {
    final payload = _asMap(data);
    if (payload != null) {
      _bumpUnreadCount(-1);
      _messageRespondedController.add(payload);
    }
  }

  Future<void> refreshUnreadCount({bool force = false}) {
    final token = _api.accessToken;
    if (token == null || token.isEmpty) {
      _setUnreadCount(0);
      return Future.value();
    }

    final now = DateTime.now();
    if (!force && _refreshUnreadCountRequest != null) {
      return _refreshUnreadCountRequest!;
    }

    if (!force &&
        _lastUnreadCountSyncAt != null &&
        now.difference(_lastUnreadCountSyncAt!) <
            const Duration(seconds: 3)) {
      return Future.value();
    }

    final request = _fetchUnreadCount();
    _refreshUnreadCountRequest = request;
    return request;
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final response = await _api.get('/messages/me/unread-count');
      final count = (response['unreadCount'] as num?)?.toInt() ?? 0;
      _setUnreadCount(count);
      _lastUnreadCountSyncAt = DateTime.now();
    } catch (_) {
      // Silenciar para no romper la UX por un badge
    } finally {
      _refreshUnreadCountRequest = null;
    }
  }

  void _bumpUnreadCount(int delta) {
    _setUnreadCount((_unreadCount + delta).clamp(0, 999));
  }

  void _setUnreadCount(int value) {
    if (_unreadCount == value) return;
    _unreadCount = value;
    if (!_unreadCountController.isClosed) {
      _unreadCountController.add(value);
    }
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}
