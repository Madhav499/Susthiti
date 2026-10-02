import '../../core/services/api_client.dart';
import '../models/system.dart';

abstract interface class NotificationRepository {
  Future<({List<AppNotification> items, int unread})> list({String status = 'all', int offset = 0});
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<NotificationPreferences> preferences();
  Future<NotificationPreferences> updatePreferences(Map<String, bool> changes);
}

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._api);
  final ApiClient _api;

  @override
  Future<({List<AppNotification> items, int unread})> list({String status = 'all', int offset = 0}) async {
    final r = await _api.get('/notifications', query: {'status': status, 'offset': offset, 'limit': 30});
    return (items: [for (final n in r['items'] as List) AppNotification.fromJson(n as Json)], unread: r['unread_count'] as int);
  }

  @override
  Future<int> unreadCount() async => (await _api.get('/notifications/unread-count'))['unread_count'] as int;

  @override
  Future<void> markRead(String id) => _api.post('/notifications/$id/read');

  @override
  Future<void> markAllRead() => _api.post('/notifications/read-all');

  @override
  Future<NotificationPreferences> preferences() async => NotificationPreferences.fromJson(await _api.get('/notifications/preferences'));

  @override
  Future<NotificationPreferences> updatePreferences(Map<String, bool> changes) async => NotificationPreferences.fromJson(await _api.put('/notifications/preferences', body: changes));
}
