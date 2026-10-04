import '../../core/utils/formatters.dart';
import 'care.dart';
import 'diabetes_risk.dart';
import 'heart_risk.dart';
import 'report.dart';
import 'tracking.dart';

class AppNotification {
  const AppNotification({required this.id, required this.type, required this.title, required this.body, required this.createdAt, required this.isRead, this.entityType, this.entityId, this.patientId});

  final String id;
  final String type;
  final String title;
  final String body;
  final String? entityType;
  final String? entityId;
  final String? patientId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification markedRead() => AppNotification(id: id, type: type, title: title, body: body, createdAt: createdAt, isRead: true, entityType: entityType, entityId: entityId, patientId: patientId);

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        entityType: j['entity_type'] as String?,
        entityId: j['entity_id'] as String?,
        patientId: j['patient_id'] as String?,
        isRead: j['is_read'] as bool,
        createdAt: parseDate(j['created_at'])!,
      );
}

class NotificationPreferences {
  const NotificationPreferences({this.foodReminders = true, this.lifestyleReminders = true, this.followUpReminders = true, this.doctorNotifications = true});
  final bool foodReminders;
  final bool lifestyleReminders;
  final bool followUpReminders;
  final bool doctorNotifications;

  factory NotificationPreferences.fromJson(Map<String, dynamic> j) => NotificationPreferences(
        foodReminders: j['food_reminders'] as bool,
        lifestyleReminders: j['lifestyle_reminders'] as bool,
        followUpReminders: j['follow_up_reminders'] as bool,
        doctorNotifications: j['doctor_notifications'] as bool,
      );
}

class PatientDashboard {
  const PatientDashboard({
    required this.patientName,
    required this.patientCode,
    required this.glucose,
    required this.metrics,
    required this.recentReports,
    this.isBirthday = false,
    this.risk,
    this.riskStale = false,
    this.riskStaleReasons = const [],
    this.heartRisk,
    this.heartRiskStale = false,
    this.heartRiskStaleReasons = const [],
    this.insightHeadline,
    this.insightGeneratedAt,
    this.nextAppointment,
    this.nextFollowUp,
    this.nextSurgery,
  });

  final String patientName;
  final String patientCode;

  /// Today is the patient's birthday (in SUSTHITI's local time zone).
  final bool isBirthday;
  /// Latest future diabetes risk estimate, and whether health data changed since.
  final RiskBrief? risk;
  final bool riskStale;
  final List<String> riskStaleReasons;
  /// Latest heart disease risk screening, and whether health data changed since. Independent
  /// of [risk]: a patient may have one, both or neither -- never a fallback between them.
  final HeartRiskBrief? heartRisk;
  final bool heartRiskStale;
  final List<String> heartRiskStaleReasons;
  final GlucoseOverview glucose;
  final Map<LifestyleMetricType, MetricOverview> metrics;
  final List<MedicalReport> recentReports;
  final String? insightHeadline;
  final DateTime? insightGeneratedAt;

  /// The soonest upcoming appointment recommendation, or the most recent one still waiting to
  /// be scheduled. Null when there is nothing to show.
  final AppointmentRecommendation? nextAppointment;

  /// The soonest follow-up still scheduled (never a completed or cancelled one).
  final FollowUpTask? nextFollowUp;

  /// The soonest surgery still scheduled. Never carries internal_notes, even for a doctor
  /// viewing this dashboard endpoint -- that field is only ever returned by the surgeries list.
  final Surgery? nextSurgery;

  factory PatientDashboard.fromJson(Map<String, dynamic> j) {
    final risk = j['diabetes_risk'] as Map<String, dynamic>?;
    final heartRisk = j['heart_risk'] as Map<String, dynamic>?;
    final insight = j['lifestyle_insight'] as Map<String, dynamic>?;
    final p = j['patient'] as Map<String, dynamic>;
    return PatientDashboard(
      patientName: p['name'] as String,
      patientCode: p['patient_code'] as String,
      isBirthday: p['is_birthday'] as bool? ?? false,
      risk: RiskBrief.maybe(risk?['latest']),
      riskStale: risk?['stale'] as bool? ?? false,
      riskStaleReasons: [for (final r in risk?['stale_reasons'] as List? ?? const []) r as String],
      heartRisk: HeartRiskBrief.maybe(heartRisk?['latest']),
      heartRiskStale: heartRisk?['stale'] as bool? ?? false,
      heartRiskStaleReasons: [for (final r in heartRisk?['stale_reasons'] as List? ?? const []) r as String],
      glucose: GlucoseOverview.fromJson(j['glucose'] as Map<String, dynamic>),
      metrics: {
        for (final e in (j['metrics'] as Map<String, dynamic>).entries) LifestyleMetricType.parse(e.key): MetricOverview.fromJson(e.value as Map<String, dynamic>),
      },
      recentReports: [for (final r in j['recent_reports'] as List) MedicalReport.fromJson(r as Map<String, dynamic>)],
      insightHeadline: insight?['headline'] as String?,
      insightGeneratedAt: parseDate(insight?['generated_at']),
      nextAppointment: j['next_appointment'] == null ? null : AppointmentRecommendation.fromJson(j['next_appointment'] as Map<String, dynamic>),
      nextFollowUp: j['next_follow_up'] == null ? null : FollowUpTask.fromJson(j['next_follow_up'] as Map<String, dynamic>),
      nextSurgery: j['next_surgery'] == null ? null : Surgery.fromJson(j['next_surgery'] as Map<String, dynamic>),
    );
  }
}

class AttentionItem {
  const AttentionItem({required this.patientId, required this.name, required this.patientCode, required this.reasons});
  final String patientId;
  final String name;
  final String patientCode;
  final List<({String reason, DateTime? at, String entityType, String entityId})> reasons;

  factory AttentionItem.fromJson(Map<String, dynamic> j) => AttentionItem(
        patientId: j['patient_id'] as String,
        name: j['name'] as String,
        patientCode: j['patient_code'] as String,
        reasons: [
          for (final r in j['reasons'] as List)
            (reason: r['reason'] as String, at: parseDate(r['at']), entityType: r['entity_type'] as String, entityId: r['entity_id'] as String),
        ],
      );
}

class ActivityItem {
  const ActivityItem({required this.actorName, required this.actorRole, required this.action, required this.createdAt, this.entityLabel, this.patientCode, this.entityType});
  final String actorName;
  final String actorRole;
  final String action;
  final String? entityLabel;
  final String? entityType;
  final String? patientCode;
  final DateTime createdAt;

  /// "Dr. XYZ created Prescription RX-000001"
  String get sentence {
    final who = actorRole == 'doctor' ? 'Dr. $actorName' : actorName;
    final what = Fmt.titleCase(action).toLowerCase();
    final label = entityLabel != null ? ' $entityLabel' : '';
    final patient = patientCode != null ? ' · $patientCode' : '';
    return '$who: $what$label$patient';
  }

  factory ActivityItem.fromJson(Map<String, dynamic> j) => ActivityItem(
        actorName: j['actor_name'] as String? ?? 'System',
        actorRole: j['actor_role'] as String? ?? 'system',
        action: j['action'] as String,
        entityLabel: j['entity_label'] as String?,
        entityType: j['entity_type'] as String?,
        patientCode: j['patient_code'] as String? ?? (j['details'] as Map?)?['patient_code'] as String?,
        createdAt: parseDate(j['created_at'])!,
      );
}

enum ScheduleItemType {
  appointment('appointment'),
  followUp('follow_up'),
  surgery('surgery');

  const ScheduleItemType(this.apiValue);
  final String apiValue;
  static ScheduleItemType parse(String v) => values.firstWhere((t) => t.apiValue == v);
}

/// One entry on a doctor's "My Day": a real appointment, follow-up or surgery for today, never
/// a fabricated task. [at] is null for a follow-up, which has no time of its own -- shown as
/// "Today", not given a made-up time.
class ScheduleItem {
  const ScheduleItem({required this.type, required this.id, required this.title, required this.patientId, this.at, this.patientName, this.patientCode});
  final ScheduleItemType type;
  final String id;
  final DateTime? at;
  final String title;
  final String patientId;
  final String? patientName;
  final String? patientCode;

  factory ScheduleItem.fromJson(Map<String, dynamic> j) => ScheduleItem(
        type: ScheduleItemType.parse(j['type'] as String),
        id: j['id'] as String,
        at: parseDate(j['at']),
        title: j['title'] as String,
        patientId: j['patient_id'] as String,
        patientName: j['patient_name'] as String?,
        patientCode: j['patient_code'] as String?,
      );
}

class DoctorDashboard {
  const DoctorDashboard({required this.doctorName, required this.metrics, required this.needsAttention, required this.recentActivity, this.today = const []});
  final String doctorName;
  final Map<String, int> metrics;
  final List<AttentionItem> needsAttention;
  final List<ActivityItem> recentActivity;

  /// Today's appointments, follow-ups and surgeries, earliest first.
  final List<ScheduleItem> today;

  factory DoctorDashboard.fromJson(Map<String, dynamic> j) => DoctorDashboard(
        doctorName: (j['doctor'] as Map<String, dynamic>)['name'] as String,
        metrics: {for (final e in (j['metrics'] as Map<String, dynamic>).entries) e.key: e.value as int},
        needsAttention: [for (final a in j['needs_attention'] as List) AttentionItem.fromJson(a as Map<String, dynamic>)],
        recentActivity: [for (final a in j['recent_activity'] as List) ActivityItem.fromJson(a as Map<String, dynamic>)],
        today: [for (final i in j['today'] as List? ?? const []) ScheduleItem.fromJson(i as Map<String, dynamic>)],
      );
}

class AdminDashboard {
  const AdminDashboard({required this.metrics, required this.recentActivity});
  final Map<String, int> metrics;
  final List<ActivityItem> recentActivity;

  factory AdminDashboard.fromJson(Map<String, dynamic> j) => AdminDashboard(
        metrics: {for (final e in (j['metrics'] as Map<String, dynamic>).entries) e.key: e.value as int},
        recentActivity: [for (final a in j['recent_activity'] as List) ActivityItem.fromJson(a as Map<String, dynamic>)],
      );
}

class AdminPatient {
  const AdminPatient({
    required this.id,
    required this.patientCode,
    required this.fullName,
    required this.email,
    required this.isActive,
    required this.createdAt,
    this.isDemo = false,
    this.lastLoginAt,
    this.lastActivityAt,
    this.approvedDoctors = 0,
    this.age,
    this.gender,
    this.latestPrediction,
    this.latestRiskCategory,
    this.latestRiskPercent,
  });
  final String id;
  final String patientCode;
  final String fullName;
  final String email;
  final bool isActive;
  final bool isDemo;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final DateTime? lastActivityAt;
  final int approvedDoctors;
  final int? age;
  final String? gender;

  /// Latest diabetes model classification (Positive / Negative), null if never assessed.
  final String? latestPrediction;
  final String? latestRiskCategory;
  final double? latestRiskPercent;

  factory AdminPatient.fromJson(Map<String, dynamic> j) => AdminPatient(
        id: j['id'] as String,
        patientCode: j['patient_code'] as String,
        fullName: j['full_name'] as String,
        email: j['email'] as String,
        isActive: j['is_active'] as bool,
        isDemo: j['is_demo'] as bool? ?? false,
        createdAt: parseDate(j['created_at'])!,
        lastLoginAt: parseDate(j['last_login_at']),
        approvedDoctors: j['approved_doctors'] as int? ?? 0,
        lastActivityAt: parseDate(j['last_activity_at']),
        age: j['age'] as int?,
        gender: j['gender'] as String?,
        latestPrediction: j['latest_prediction'] as String?,
        latestRiskCategory: j['latest_risk_category'] as String?,
        latestRiskPercent: (j['latest_risk_percent'] as num?)?.toDouble(),
      );
}

class AuditEntry {
  const AuditEntry({required this.id, required this.createdAt, required this.action, this.actorName, this.actorRole, this.entityType, this.entityLabel, this.details = const {}});
  final String id;
  final DateTime createdAt;
  final String action;
  final String? actorName;
  final String? actorRole;
  final String? entityType;
  final String? entityLabel;
  final Map<String, dynamic> details;

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: j['id'] as String,
        createdAt: parseDate(j['created_at'])!,
        action: j['action'] as String,
        actorName: j['actor_name'] as String?,
        actorRole: j['actor_role'] as String?,
        entityType: j['entity_type'] as String?,
        entityLabel: j['entity_label'] as String?,
        details: Map<String, dynamic>.from(j['details'] as Map? ?? const {}),
      );
}

/// Delivery status only, for admin monitoring -- the backend never sends a notification's
/// title or body here, since that's free text that can name a patient or carry clinical detail.
class NotificationDeliveryEntry {
  const NotificationDeliveryEntry({required this.id, required this.type, required this.createdAt, this.recipientRole, this.pushStatus});
  final String id;
  final String type;
  final String? recipientRole;

  /// "sent", "failed", or null (nothing attempted: FCM unconfigured, or no registered device).
  final String? pushStatus;
  final DateTime createdAt;

  factory NotificationDeliveryEntry.fromJson(Map<String, dynamic> j) => NotificationDeliveryEntry(
        id: j['id'] as String,
        type: j['type'] as String,
        recipientRole: j['recipient_role'] as String?,
        pushStatus: j['push_status'] as String?,
        createdAt: parseDate(j['created_at'])!,
      );
}

class SystemSettings {
  const SystemSettings({required this.values, required this.status});
  final Map<String, String> values;
  final Map<String, dynamic> status;

  factory SystemSettings.fromJson(Map<String, dynamic> j) => SystemSettings(
        values: {for (final e in (j['values'] as Map<String, dynamic>).entries) e.key: e.value as String},
        status: Map<String, dynamic>.from(j['status'] as Map),
      );
}
