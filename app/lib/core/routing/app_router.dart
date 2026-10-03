import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/patient.dart';
import '../../data/models/user.dart';
import '../../features/access/access_screens.dart';
import '../../features/admin/admin_doctor_profile_screen.dart';
import '../../features/admin/admin_patient_profile_screen.dart';
import '../../features/admin/admin_screens.dart';
import '../../features/ai/ai_screens.dart';
import '../../features/authentication/auth_controller.dart';
import '../../features/authentication/auth_layout.dart';
import '../../features/authentication/login_screen.dart';
import '../../features/authentication/password_recovery_screens.dart';
import '../../features/authentication/register_screen.dart';
import '../../features/authentication/splash_screen.dart';
import '../../features/diabetes/assessment_detail_screen.dart';
import '../../features/diabetes/risk_detail_screen.dart';
import '../../features/diabetes/diabetes_questionnaire_screen.dart';
import '../../features/diabetes/diabetes_screen.dart';
import '../../features/doctor/doctor_dashboard_screen.dart';
import '../../features/doctor/doctor_patient_detail_screen.dart';
import '../../features/doctor/doctor_patients_screens.dart';
import '../../features/follow_ups/follow_ups_screens.dart';
import '../../features/food/food_screen.dart';
import '../../features/glucose/glucose_screen.dart';
import '../../features/health_profile/health_profile_screen.dart';
import '../../features/lifestyle/lifestyle_screen.dart';
import '../../features/notifications/notifications.dart';
import '../../features/patient/patient_dashboard_screen.dart';
import '../../features/patient/profile_screen.dart';
import '../../features/patient/timeline_screen.dart';
import '../../features/prescriptions/prescriptions_screens.dart';
import '../../features/reports/all_reports_summary_screen.dart';
import '../../features/reports/report_detail_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/reports/upload_report_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/side_effects/side_effects_screens.dart';
import '../../features/surgery/surgery_screens.dart';
import '../../features/visits/visits_screens.dart';
import '../../features/wearables/devices_screen.dart';
import '../../features/wearables/health_connect_screen.dart';
import '../widgets/feedback.dart';
import 'role_shell.dart';

const _publicRoutes = {'/login', '/register', '/forgot-password', '/reset-password'};

String homeFor(UserRole role) => switch (role) {
      UserRole.patient => '/p/home',
      UserRole.doctor => '/d/home',
      UserRole.admin => '/a/home',
    };

/// UI-level role gate. The backend enforces the same rules on every request; this only keeps
/// users out of screens they could never load.
String? roleRedirect(AppUser? user, Uri uri, {required bool loading}) {
  final path = uri.path;
  // While the session restores, wait on the splash but remember the requested page, so a
  // reload or shared link (e.g. /a/patients/p1?tab=reports) lands where it pointed.
  if (loading) {
    if (path == '/splash') return null;
    return path == '/' ? '/splash' : Uri(path: '/splash', queryParameters: {'from': uri.toString()}).toString();
  }
  if (user == null) {
    return _publicRoutes.contains(path) ? null : '/login';
  }
  if (path == '/splash') {
    final from = uri.queryParameters['from'];
    if (from != null && from.startsWith('/') && !from.startsWith('/splash')) {
      final target = Uri.parse(from);
      if (!_publicRoutes.contains(target.path) && roleRedirect(user, target, loading: false) == null) return from;
    }
    return homeFor(user.role);
  }
  if (_publicRoutes.contains(path) || path == '/') return homeFor(user.role);

  final allowed = switch (user.role) {
    UserRole.patient => path.startsWith('/p/') || (path.startsWith('/r/') && path.split('/')[2] == user.patientId),
    UserRole.doctor => path.startsWith('/d/') || path.startsWith('/r/'),
    // Admin reads any record screen (read-only; the backend refuses clinical writes) but uploads
    // only through the admin upload route, which records the admin as uploader.
    UserRole.admin => path.startsWith('/a/') || (path.startsWith('/r/') && !path.endsWith('/reports/upload')),
  };
  return allowed ? null : homeFor(user.role);
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Bridges the auth state into go_router's refresh mechanism.
class _AuthRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.ping());
  ref.listen(splashGateProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  String pid() => ref.read(currentUserProvider)?.patientId ?? '';

  GoRoute page(String path, Widget Function(GoRouterState s) build) =>
      GoRoute(path: path, parentNavigatorKey: _rootKey, builder: (context, s) => build(s));

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      // Stay on the splash until the session is restored AND the logo animation has played.
      final starting = (auth.isLoading && !auth.hasValue) || !ref.read(splashGateProvider);
      return roleRedirect(auth.value, state.uri, loading: starting);
    },
    errorBuilder: (context, state) => const _NotFoundScreen(),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset-password', builder: (_, s) => ResetPasswordScreen(prefilledToken: s.extra as String?)),

      // ---------- Patient: full-screen pages over the shell ----------
      page('/p/notifications', (_) => const NotificationsScreen()),
      page('/p/settings', (_) => const SettingsScreen()),
      page('/p/access', (_) => const AccessRequestsScreen()),
      page('/p/devices', (_) => const DevicesScreen()),
      page('/p/devices/connect', (_) => const HealthConnectScreen()),
      page('/p/glucose', (_) => GlucoseScreen(patientId: pid())),
      page('/p/food', (_) => FoodScreen(patientId: pid())),
      page('/p/lifestyle/insight', (_) => LifestyleInsightScreen(patientId: pid())),
      page('/p/diabetes/assess', (_) => DiabetesQuestionnaireScreen(patientId: pid())),
      page('/p/side-effects/new', (_) => ReportSideEffectScreen(patientId: pid())),
      page('/p/timeline', (_) => TimelineScreen(patientId: pid())),
      page('/p/appointments', (_) => AppointmentsScreen(patientId: pid())),
      page('/p/follow-ups', (_) => FollowUpsScreen(patientId: pid())),
      page('/p/surgeries', (_) => SurgeryScreen(patientId: pid())),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RoleShell(shell: shell, header: const BrandMark(size: 30), accountRoute: '/p/profile', links: [
          const ShellLink('Glucose', Icons.water_drop_outlined, '/p/glucose'),
          const ShellLink('Food log', Icons.restaurant_outlined, '/p/food'),
          ShellLink('Prescriptions', Icons.medication_outlined, '/r/${pid()}/prescriptions'),
          const ShellLink('Appointments', Icons.event_outlined, '/p/appointments'),
          const ShellLink('Follow-ups', Icons.event_repeat_outlined, '/p/follow-ups'),
          const ShellLink('Surgeries', Icons.local_hospital_outlined, '/p/surgeries'),
          ShellLink('Side effects', Icons.healing_outlined, '/r/${pid()}/side-effects'),
          const ShellLink('History', Icons.timeline_outlined, '/p/timeline'),
          const ShellLink('Notifications', Icons.notifications_none_outlined, '/p/notifications'),
          const ShellLink('Settings', Icons.settings_outlined, '/p/settings'),
        ], destinations: const [
          ShellDestination('Home', Icons.home_outlined, Icons.home),
          ShellDestination('Reports', Icons.description_outlined, Icons.description),
          ShellDestination('Lifestyle', Icons.directions_walk_outlined, Icons.directions_walk),
          ShellDestination('Diabetes', Icons.fact_check_outlined, Icons.fact_check),
          ShellDestination('Profile', Icons.person_outline, Icons.person),
        ]),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/p/home', builder: (_, _) => PatientDashboardScreen(patientId: pid()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/p/reports', builder: (_, _) => ReportsScreen(patientId: pid()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/p/lifestyle', builder: (_, _) => LifestyleScreen(patientId: pid()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/p/diabetes', builder: (_, _) => DiabetesScreen(patientId: pid()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/p/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),

      // ---------- Doctor ----------
      page('/d/notifications', (_) => const NotificationsScreen()),
      page('/d/patients/add', (_) => const AddPatientScreen()),
      page('/d/patients/:pid', (s) => DoctorPatientDetailScreen(patientId: s.pathParameters['pid']!, initialTab: int.tryParse(s.uri.queryParameters['tab'] ?? '') ?? 0)),
      page('/d/patients/:pid/prescriptions/new', (s) => CreatePrescriptionScreen(patientId: s.pathParameters['pid']!)),
      page('/d/patients/:pid/visits/new', (s) => RecordVisitScreen(patientId: s.pathParameters['pid']!)),
      page('/d/patients/:pid/timeline', (s) => TimelineScreen(patientId: s.pathParameters['pid']!)),
      page('/d/patients/:pid/food', (s) => FoodScreen(patientId: s.pathParameters['pid']!, canLog: false)),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RoleShell(shell: shell, header: const BrandMark(size: 30), accountRoute: '/d/settings', links: const [
          ShellLink('Add patient', Icons.person_add_alt_outlined, '/d/patients/add'),
          ShellLink('Notifications', Icons.notifications_none_outlined, '/d/notifications'),
        ], destinations: const [
          ShellDestination('Dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard),
          ShellDestination('Patients', Icons.people_outline, Icons.people),
          ShellDestination('Requests', Icons.verified_user_outlined, Icons.verified_user),
          ShellDestination('Account', Icons.manage_accounts_outlined, Icons.manage_accounts),
        ]),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/d/home', builder: (_, _) => const DoctorDashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/d/patients', builder: (_, s) => DoctorPatientsScreen(initialFilter: s.uri.queryParameters['filter'] ?? 'all'))]),
          StatefulShellBranch(routes: [GoRoute(path: '/d/requests', builder: (_, _) => const AccessRequestsScreen(large: true))]),
          StatefulShellBranch(routes: [GoRoute(path: '/d/settings', builder: (_, _) => const SettingsScreen(large: true))]),
        ],
      ),

      // ---------- Admin ----------
      // Viewing and editing are separate routes: a doctor or patient opens their profile; the
      // edit forms are reached from an explicit Edit action.
      page('/a/doctors/new', (_) => const DoctorFormScreen()),
      page('/a/doctors/:id', (s) => _adminFrame(1, AdminDoctorProfileScreen(doctorId: s.pathParameters['id']!, initialTab: s.uri.queryParameters['tab']))),
      page('/a/doctors/:id/edit', (s) => s.extra is DoctorProfile ? DoctorFormScreen(doctor: s.extra as DoctorProfile) : EditDoctorLoader(doctorId: s.pathParameters['id']!)),
      page('/a/patients/:pid', (s) => _adminFrame(2, AdminPatientProfileScreen(patientId: s.pathParameters['pid']!, initialTab: s.uri.queryParameters['tab']))),
      page('/a/patients/:pid/edit', (s) => AdminPatientEditScreen(patientId: s.pathParameters['pid']!)),
      page('/a/patients/:pid/upload', (s) => UploadReportScreen(patientId: s.pathParameters['pid']!, asAdmin: true)),
      page('/a/audit', (_) => const AuditLogsScreen()),
      page('/a/notifications', (_) => const NotificationDeliveryScreen()),
      page('/a/system', (_) => const SystemSettingsScreen()),
      page('/a/account', (_) => const SettingsScreen()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RoleShell(shell: shell, header: const BrandMark(size: 30), accountRoute: '/a/more', links: _adminLinks, destinations: _adminDestinations),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/a/home', builder: (_, _) => const AdminDashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/a/doctors', builder: (_, _) => const AdminDoctorsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/a/patients', builder: (_, _) => const AdminPatientsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/a/access', builder: (_, _) => const AccessRequestsScreen(large: true))]),
          StatefulShellBranch(routes: [GoRoute(path: '/a/more', builder: (_, _) => const AdminMoreScreen())]),
        ],
      ),

      // ---------- Shared patient records (patient: own; doctor: approved access only; admin: read-only) ----------
      page('/r/:pid/reports', (s) => ReportsScreen(patientId: s.pathParameters['pid']!)),
      page('/r/:pid/reports/upload', (s) => UploadReportScreen(patientId: s.pathParameters['pid']!)),
      page('/r/:pid/reports/:rid', (s) => ReportDetailScreen(patientId: s.pathParameters['pid']!, reportId: s.pathParameters['rid']!)),
      page('/r/:pid/reports-summary', (s) => AllReportsSummaryScreen(patientId: s.pathParameters['pid']!)),
      page('/r/:pid/patient-summary', (s) => PatientSummaryScreen(patientId: s.pathParameters['pid']!)),
      page('/r/:pid/assessments/:aid', (s) => AssessmentDetailScreen(assessmentId: s.pathParameters['aid']!)),
      page('/r/:pid/diabetes-risk/:aid', (s) => RiskDetailScreen(patientId: s.pathParameters['pid']!, assessmentId: s.pathParameters['aid']!)),
      page('/r/:pid/health-profile', (s) => HealthProfileScreen(patientId: s.pathParameters['pid']!)),
      page('/r/:pid/prescriptions', (s) => PrescriptionsScreen(patientId: s.pathParameters['pid']!)),
      page('/r/:pid/prescriptions/:id', (s) => PrescriptionDetailScreen(prescriptionId: s.pathParameters['id']!)),
      page('/r/:pid/visits', (s) => VisitsScreen(patientId: s.pathParameters['pid']!)),
      page('/r/:pid/visits/:id', (s) => VisitDetailScreen(visitId: s.pathParameters['id']!)),
      page('/r/:pid/side-effects', (s) => SideEffectsScreen(patientId: s.pathParameters['pid']!)),
      page('/r/:pid/side-effects/:id', (s) => SideEffectDetailScreen(patientId: s.pathParameters['pid']!, sideEffectId: s.pathParameters['id']!)),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

const _adminDestinations = [
  ShellDestination('Dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard),
  ShellDestination('Doctors', Icons.medical_services_outlined, Icons.medical_services),
  ShellDestination('Patients', Icons.people_outline, Icons.people),
  ShellDestination('Access', Icons.verified_user_outlined, Icons.verified_user),
  ShellDestination('More', Icons.more_horiz, Icons.more_horiz),
];
const _adminRoutes = ['/a/home', '/a/doctors', '/a/patients', '/a/access', '/a/more'];
const _adminLinks = [
  ShellLink('Audit logs', Icons.receipt_long_outlined, '/a/audit'),
  ShellLink('Notification delivery', Icons.notifications_none_outlined, '/a/notifications'),
  ShellLink('System settings', Icons.tune_outlined, '/a/system'),
  ShellLink('Add doctor', Icons.person_add_alt_outlined, '/a/doctors/new'),
];

/// Admin profile pages keep the admin sidebar on tablet and desktop.
Widget _adminFrame(int selected, Widget child) => RoleFrame(
      destinations: _adminDestinations,
      routes: _adminRoutes,
      selected: selected,
      links: _adminLinks,
      header: const BrandMark(size: 30),
      accountRoute: '/a/more',
      child: child,
    );

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: EmptyState(icon: Icons.search_off, title: 'Page not found.', actionLabel: 'Go home', onAction: () => context.go('/')),
      ),
    );
  }
}
