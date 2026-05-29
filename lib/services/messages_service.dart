import 'api_service.dart';

class MessagesService {
  final ApiService _api;

  MessagesService(this._api);

  Future<int> getUnreadCount() async {
    final response = await _api.get('/messages/me/unread-count');
    return (response as Map<String, dynamic>)['unreadCount'] as int? ?? 0;
  }
}
