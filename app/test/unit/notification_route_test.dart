import 'package:flutter_test/flutter_test.dart';
import 'package:susthiti/data/models/system.dart';
import 'package:susthiti/data/models/user.dart';
import 'package:susthiti/features/notifications/notifications.dart';

void main() {
  const patient = AppUser(id: 'u1', email: 'p@example.org', role: UserRole.patient, fullName: 'Pat', patientId: 'pat1');

  AppNotification lifestyle(String? metric) => AppNotification(
        id: 'n1', type: 'lifestyle_reminder', title: 'Daily Lifestyle Reminder', body: 'body',
        createdAt: DateTime.now(), isRead: false, entityType: 'lifestyle_metric', entityId: metric, patientId: 'pat1',
      );

  test('a glucose reminder routes to the glucose screen', () {
    expect(notificationRoute(lifestyle('glucose'), patient), '/p/glucose');
  });

  test('a food reminder routes to the food screen', () {
    expect(notificationRoute(lifestyle('food'), patient), '/p/food');
  });

  test('any other metric routes to Lifestyle with the metric preselected', () {
    expect(notificationRoute(lifestyle('steps'), patient), '/p/lifestyle?metric=steps');
    expect(notificationRoute(lifestyle('heart_rate'), patient), '/p/lifestyle?metric=heart_rate');
  });

  test('a missing metric still opens Lifestyle, just without a preselection', () {
    expect(notificationRoute(lifestyle(null), patient), '/p/lifestyle');
  });
}
