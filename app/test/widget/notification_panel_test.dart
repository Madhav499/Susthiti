import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:susthiti/core/theme/app_theme.dart';
import 'package:susthiti/data/models/system.dart';
import 'package:susthiti/data/providers.dart';
import 'package:susthiti/data/repositories/notification_repository.dart';
import 'package:susthiti/features/authentication/auth_controller.dart';
import 'package:susthiti/features/notifications/notifications.dart';

import '../helpers.dart';

class MockNotificationRepository extends Mock implements NotificationRepository {}

void main() {
  late MockNotificationRepository repo;
  final items = [
    AppNotification(id: 'n1', type: 'report', title: 'New report uploaded', body: 'CBC results are ready', createdAt: DateTime.now(), isRead: false, entityType: 'report', entityId: 'r1', patientId: 'pat1'),
    AppNotification(id: 'n2', type: 'appointment', title: 'Appointment confirmed', body: 'Tomorrow at 10:00', createdAt: DateTime.now(), isRead: true, entityType: 'appointment'),
  ];

  setUp(() {
    repo = MockNotificationRepository();
    when(() => repo.list(status: any(named: 'status'))).thenAnswer((_) async => (items: items, unread: 1));
    when(() => repo.unreadCount()).thenAnswer((_) async => 1);
    when(() => repo.markRead(any())).thenAnswer((_) async {});
  });

  Future<void> pumpBell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(appBar: AppBar(actions: const [NotificationBell()]))),
      GoRoute(path: '/p/notifications', builder: (_, _) => const Text('ALL NOTIFICATIONS')),
      GoRoute(path: '/r/:pid/reports/:id', builder: (_, s) => Text('REPORT ${s.pathParameters['id']}')),
    ]);
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [currentUserProvider.overrideWithValue(testPatient), notificationRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('desktop: the bell opens a panel of recent notifications', (tester) async {
    await pumpBell(tester, const Size(1280, 900));
    await tester.tap(find.byType(NotificationBell));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationPanel), findsOneWidget);
    expect(find.text('New report uploaded'), findsOneWidget);
    expect(find.text('Appointment confirmed'), findsOneWidget);
    expect(find.text('View all notifications'), findsOneWidget);

    await tester.tap(find.text('New report uploaded'));
    await tester.pumpAndSettle();
    verify(() => repo.markRead('n1')).called(1);
    expect(find.text('REPORT r1'), findsOneWidget);
  });

  testWidgets('desktop: View all opens the full notifications screen', (tester) async {
    await pumpBell(tester, const Size(1280, 900));
    await tester.tap(find.byType(NotificationBell));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all notifications'));
    await tester.pumpAndSettle();
    expect(find.text('ALL NOTIFICATIONS'), findsOneWidget);
  });

  testWidgets('phone: the bell goes straight to the notifications screen', (tester) async {
    await pumpBell(tester, const Size(390, 844));
    await tester.tap(find.byType(NotificationBell));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationPanel), findsNothing);
    expect(find.text('ALL NOTIFICATIONS'), findsOneWidget);
  });
}
