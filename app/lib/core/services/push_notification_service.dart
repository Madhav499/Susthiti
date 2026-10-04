import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/models/system.dart';
import '../../data/models/user.dart';
import '../../data/repositories/notification_repository.dart';
import '../../features/notifications/notifications.dart' show notificationRoute;

/// Mirrors the channel ids `push.py`'s `_channel_for()` picks server-side -- a push and a
/// same-event foreground local notification must land on the same channel. Only four, each for
/// a genuinely different notification feel (mutable per-channel in Android settings), not one
/// per notification type.
const _channels = [
  AndroidNotificationChannel('susthiti_important', 'SUSTHITI Important',
      description: 'Access requests and reminders due today or tomorrow', importance: Importance.max),
  AndroidNotificationChannel('susthiti_appointments', 'SUSTHITI Appointments',
      description: 'Appointment, follow-up and surgery scheduling changes', importance: Importance.high),
  AndroidNotificationChannel('susthiti_health', 'SUSTHITI Health Updates',
      description: 'New reports, prescriptions and visit records', importance: Importance.defaultImportance),
  AndroidNotificationChannel('susthiti_general', 'SUSTHITI General',
      description: 'Lifestyle reminders and other routine updates', importance: Importance.defaultImportance),
];
const _defaultChannelId = 'susthiti_general';
const _notificationIcon = '@mipmap/ic_stat_notify';

/// Same grouping `push.py`'s `_channel_for()` uses -- kept in sync by hand since one side is
/// Dart and the other Python. Public (not `_`-prefixed) so a test can assert the two stay in
/// sync; see test/unit/push_channel_test.dart.
String channelFor(String? type) {
  const important = {'access_request', 'surgery_reminder', 'follow_up_reminder'};
  const appointments = {
    'appointment_recommendation', 'follow_up_scheduled', 'follow_up_rescheduled', 'follow_up_cancelled',
    'surgery_scheduled', 'surgery_rescheduled', 'surgery_cancelled', 'access_approved',
  };
  const health = {'new_report', 'report_summary_ready', 'new_prescription', 'visit_recorded', 'access_rejected', 'access_revoked'};
  if (important.contains(type)) return 'susthiti_important';
  if (appointments.contains(type)) return 'susthiti_appointments';
  if (health.contains(type)) return 'susthiti_health';
  return _defaultChannelId;
}

/// Required by firebase_messaging for background/terminated-app delivery; must stay a
/// top-level function. Left minimal on purpose: Android's FCM SDK already renders the system
/// notification itself for every message this backend sends (each one carries a `notification`
/// payload, never a silent data-only one), so nothing here needs to touch the Flutter engine.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Push notifications end-to-end: permission, token lifecycle, foreground display (Android
/// doesn't show FCM's own notification while the app is open, so this surfaces it through
/// flutter_local_notifications instead), and tap-to-navigate. Every step is wrapped so a
/// missing or invalid Firebase project degrades to "no system push" rather than a crash --
/// this is deliberately safe to call before any Firebase project exists.
class PushNotificationService {
  PushNotificationService(this._notifications);
  final NotificationRepository _notifications;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  /// Set by the app shell once the router is available.
  void Function(String route)? onNavigate;

  /// Set by the app shell; used to resolve a push's deep link the same way an in-app
  /// notification resolves one (role-aware — see notificationRoute).
  AppUser? Function()? currentUser;

  bool _ready = false;
  String? _registeredToken;

  /// A tap that arrived before the session finished restoring (see [_handleTap]) -- resolved
  /// once a signed-in user is available, by [retryBufferedTap].
  Map<String, dynamic>? _pendingTapData;

  /// Sets up messaging plumbing but never prompts for permission here -- that happens in
  /// [registerForCurrentUser], once there's actually a signed-in user notifications are for.
  /// Asking at bare app launch, before login, would be exactly the premature prompt a
  /// sensible permission flow avoids.
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Expected until a Firebase project exists and google-services.json is in place. The
      // app continues exactly as before; only system push is unavailable.
      if (kDebugMode) debugPrint('[push] Firebase not configured, system push disabled: $e');
      return;
    }
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _initLocalNotifications();
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
      _ready = true;
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleTap(initial);
    } catch (e) {
      if (kDebugMode) debugPrint('[push] setup failed: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in _channels) {
      await android?.createNotificationChannel(channel);
    }
    await _local.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings(_notificationIcon)),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) onNavigate?.call(route);
      },
    );
  }

  /// Call once a user is signed in, and again on every app launch while already signed in --
  /// a no-op when the token hasn't changed since it was last registered. The permission prompt
  /// lives here rather than in [initialize] specifically so it only appears for someone who is
  /// actually signed in, never at a bare app launch on the login screen. A denial still lets
  /// this return normally: no token is registered, and in-app notifications are unaffected.
  Future<void> registerForCurrentUser() async {
    if (!_ready) return;
    final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    if (token == _registeredToken) return;
    try {
      await _notifications.registerDeviceToken(token, platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
      _registeredToken = token;
    } catch (e) {
      if (kDebugMode) debugPrint('[push] token registration failed: $e');
    }
  }

  /// Call on logout, before (or after) the session itself is cleared.
  Future<void> unregister() async {
    final token = _registeredToken;
    _registeredToken = null;
    if (token == null) return;
    try {
      await _notifications.unregisterDeviceToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint('[push] token unregister failed: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;
    final route = _routeFor(message.data);
    final id = (message.data['notification_id'] as String?)?.hashCode ?? message.hashCode;
    final channel = _channels.firstWhere((c) => c.id == channelFor(message.data['type'] as String?));
    _local.show(
      id: id,
      title: notif.title,
      body: notif.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id, channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: channel.importance.value >= Importance.high.value ? Priority.high : Priority.defaultPriority,
          icon: _notificationIcon,
        ),
      ),
      payload: route,
    );
  }

  void _handleTap(RemoteMessage message) {
    final notificationId = message.data['notification_id'] as String?;
    if (notificationId != null && notificationId.isNotEmpty) {
      // Independent of AuthController's session restore -- ApiClient reads the persisted token
      // directly from storage, so this already works even during the race handled below.
      _notifications.markRead(notificationId).catchError((_) {});
    }
    if (currentUser?.call() == null) {
      // Cold start: a tap launched the app, but the session hasn't finished restoring yet, so
      // there's no signed-in user to resolve a role-aware route for. Buffer it instead of
      // dropping it -- retryBufferedTap() (called from app.dart once sign-in resolves) finishes
      // the job.
      _pendingTapData = message.data;
      return;
    }
    final route = _routeFor(message.data);
    if (route != null) onNavigate?.call(route);
  }

  /// Call once a user becomes signed in (including a session restored on cold launch), to
  /// resolve a tap that arrived before that finished. A no-op if nothing is buffered.
  void retryBufferedTap() {
    final data = _pendingTapData;
    if (data == null) return;
    _pendingTapData = null;
    final route = _routeFor(data);
    if (route != null) onNavigate?.call(route);
  }

  /// Reuses the exact same routing the in-app notification bell uses, so a push and its
  /// in-app counterpart always lead to the same screen.
  String? _routeFor(Map<String, dynamic> data) {
    final user = currentUser?.call();
    if (user == null) return null;
    final notification = AppNotification(
      id: data['notification_id'] as String? ?? '',
      type: data['type'] as String? ?? '',
      title: '',
      body: '',
      createdAt: DateTime.now(),
      isRead: false,
      entityType: data['entity_type'] as String?,
      entityId: data['entity_id'] as String?,
      patientId: data['patient_id'] as String?,
    );
    return notificationRoute(notification, user);
  }
}
