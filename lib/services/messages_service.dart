import 'api_service.dart';

class MessagesService {
  final ApiService _api;

  MessagesService(this._api);

  Future<List<dynamic>> getMessages({String filter = 'all'}) async {
    final query = filter == 'all' ? '' : '?filter=$filter';
    final response = await _api.get('/messages/me$query');
    return response as List<dynamic>;
  }

  Future<int> getUnreadCount() async {
    final response = await _api.get('/messages/me/unread-count');
    return (response as Map<String, dynamic>)['unreadCount'] as int? ?? 0;
  }

  Future<void> markRead(String id) async {
    await _api.patch('/messages/$id/read', {});
  }
}
