import 'package:flutter_test/flutter_test.dart';
import 'package:susthiti/core/services/push_notification_service.dart';

void main() {
  // Every notification `type` the backend actually calls `notify(...)` with (see
  // backend/app/routers and backend/app/services) -- mirrors
  // test_push_channel_assignment_matches_every_notification_type_in_use on the Python side so a
  // drift between the two gets caught on both ends, not just one.
  const usedTypes = {
    'access_request', 'access_approved', 'access_rejected', 'access_revoked',
    'appointment_recommendation', 'doctor_response', 'visit_recorded', 'new_prescription',
    'follow_up_scheduled', 'follow_up_cancelled', 'follow_up_rescheduled', 'follow_up_reminder',
    'surgery_scheduled', 'surgery_rescheduled', 'surgery_cancelled', 'surgery_reminder',
    'new_report', 'report_summary_ready', 'food_reminder', 'lifestyle_reminder', 'birthday',
  };
  const validChannels = {'susthiti_important', 'susthiti_appointments', 'susthiti_health', 'susthiti_general'};

  test('every notification type in use resolves to a real channel', () {
    for (final type in usedTypes) {
      expect(validChannels.contains(channelFor(type)), isTrue, reason: '"$type" resolved to an unknown channel');
    }
  });

  test('routine, non-actionable types are never the important channel', () {
    expect(channelFor('food_reminder'), 'susthiti_general');
    expect(channelFor('birthday'), 'susthiti_general');
    expect(channelFor('lifestyle_reminder'), 'susthiti_general');
  });

  test('time-sensitive reminders land on the important channel', () {
    expect(channelFor('surgery_reminder'), 'susthiti_important');
    expect(channelFor('follow_up_reminder'), 'susthiti_important');
    expect(channelFor('access_request'), 'susthiti_important');
  });

  test('an unmapped or missing type defaults to general, not important', () {
    expect(channelFor(null), 'susthiti_general');
    expect(channelFor('some_future_type_nobody_mapped_yet'), 'susthiti_general');
  });
}
