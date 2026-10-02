import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/debouncer.dart';
import '../../core/utils/formatters.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/labels.dart';
import '../../core/widgets/responsive_table.dart';
import '../../data/models/patient.dart';
import '../../data/models/system.dart';
import '../../data/providers.dart';
import '../authentication/auth_controller.dart';
import 'admin_common.dart';

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboard>((ref) => ref.watch(adminRepositoryProvider).dashboard());

typedef AdminListKey = ({String query, String status});
final adminDoctorsProvider = FutureProvider.autoDispose.family<List<DoctorProfile>, AdminListKey>((ref, k) => ref.watch(adminRepositoryProvider).doctors(query: k.query, status: k.status));
typedef AdminPatientsKey = ({String query, String status});
final adminPatientsProvider =
    FutureProvider.autoDispose.family<({List<AdminPatient> items, int total}), AdminPatientsKey>((ref, k) => ref.watch(adminRepositoryProvider).patients(query: k.query, status: k.status));
final auditLogsProvider = FutureProvider.autoDispose.family<({List<AuditEntry> items, int total}), String>((ref, q) => ref.watch(adminRepositoryProvider).auditLogs(query: q));
final systemSettingsProvider = FutureProvider.autoDispose<SystemSettings>((ref) => ref.watch(adminRepositoryProvider).settings());

/// Admins manage accounts and access, and can open any doctor's or patient's complete record
/// (read-only) from the lists.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'Admin',
      large: true,
      body: PageBody(onRefresh: () async => ref.invalidate(adminDashboardProvider), children: [
        AsyncBody(
          value: ref.watch(adminDashboardProvider),
          onRetry: () => ref.invalidate(adminDashboardProvider),
          data: (d) {
            int m(String k) => d.metrics[k] ?? 0;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ResponsiveGrid(minItemWidth: 170, maxColumns: 5, children: [
                MetricTile(icon: Icons.medical_services_outlined, label: 'Doctors', value: '${m('total_doctors')}', caption: '${m('active_doctors')} active', onTap: () => context.go('/a/doctors')),
                MetricTile(icon: Icons.people_outline, label: 'Patients', value: '${m('total_patients')}', caption: 'registered', onTap: () => context.go('/a/patients')),
                MetricTile(icon: Icons.person_pin_outlined, label: 'Active patients', value: '${m('active_patients')}', caption: 'in the last 30 days'),
                MetricTile(icon: Icons.hourglass_empty, label: 'Pending requests', value: '${m('pending_requests')}', caption: 'doctor access', onTap: () => context.go('/a/access')),
              ]),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader('Quick actions'),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                FilledButton.icon(onPressed: () => context.push('/a/doctors/new'), icon: const Icon(Icons.person_add_alt_outlined), label: const Text('Add Doctor')),
                OutlinedButton.icon(onPressed: () => context.push('/a/audit'), icon: const Icon(Icons.receipt_long_outlined), label: const Text('Audit Logs')),
                OutlinedButton.icon(onPressed: () => context.push('/a/system'), icon: const Icon(Icons.tune), label: const Text('System Settings')),
              ]),
              const SizedBox(height: AppSpacing.section),
              SectionHeader('Recent activity', action: TextButton(onPressed: () => context.push('/a/audit'), child: const Text('View all'))),
              AppCard(
                child: d.recentActivity.isEmpty
                    ? Text('No activity yet.', style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        for (final a in d.recentActivity)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.sentence, style: t.bodyMedium), Text(Fmt.relative(a.createdAt), style: t.bodySmall)]),
                          ),
                      ]),
              ),
            ]);
          },
        ),
      ]),
    );
  }
}

class AdminDoctorsScreen extends ConsumerStatefulWidget {
  const AdminDoctorsScreen({super.key});

  @override
  ConsumerState<AdminDoctorsScreen> createState() => _AdminDoctorsScreenState();
}

/// Doctor list. A row (or View Profile) opens the doctor's profile; editing is a separate action.
class _AdminDoctorsScreenState extends ConsumerState<AdminDoctorsScreen> {
  final _debouncer = Debouncer();
  String _query = '';
  String _status = 'all';

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _toggle(DoctorProfile d) async {
    if (d.isActive) {
      final ok = await confirmAction(context,
          title: 'Deactivate Dr. ${d.fullName}?', message: 'They will be signed out and cannot sign in. Their past records remain in patient histories.', confirmLabel: 'Deactivate', destructive: true);
      if (!ok) return;
    }
    try {
      await ref.read(adminRepositoryProvider).updateDoctor(d.id, {'is_active': !d.isActive});
      ref.invalidate(adminDoctorsProvider);
      ref.invalidate(adminDoctorProvider(d.id));
      if (mounted) showToast(context, d.isActive ? 'Doctor deactivated' : 'Doctor reactivated');
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  void _action(DoctorProfile d, String action) => switch (action) {
        'edit' => context.push('/a/doctors/${d.id}/edit'),
        'patients' => context.push(adminDoctorRoute(d.id, tab: 'patients')),
        'activity' => context.push(adminDoctorRoute(d.id, tab: 'activity')),
        'toggle' => _toggle(d),
        _ => context.push(adminDoctorRoute(d.id)),
      };

  Widget _menu(DoctorProfile d) => PopupMenuButton<String>(
        tooltip: 'Actions for Dr. ${d.fullName}',
        icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
        onSelected: (a) => _action(d, a),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'view', child: Text('View profile')),
          const PopupMenuItem(value: 'edit', child: Text('Edit doctor')),
          const PopupMenuItem(value: 'patients', child: Text('View patients')),
          const PopupMenuItem(value: 'activity', child: Text('View activity')),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'toggle', child: Text(d.isActive ? 'Deactivate' : 'Reactivate', style: TextStyle(color: d.isActive ? AppColors.errorText : null))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final key = (query: _query, status: _status);
    final t = Theme.of(context).textTheme;
    final mobile = context.screenSize == ScreenSize.mobile;
    String lastActive(DoctorProfile d) => d.lastActivityAt == null ? 'No activity yet' : 'Last active ${Fmt.relative(d.lastActivityAt)}';
    return AppPage(
      title: 'Doctors',
      large: true,
      actions: [
        if (!mobile) FilledButton.icon(onPressed: () => context.push('/a/doctors/new'), icon: const Icon(Icons.person_add_alt_outlined, size: 18), label: const Text('Add Doctor')),
      ],
      floatingActionButton: mobile ? FloatingActionButton.extended(onPressed: () => context.push('/a/doctors/new'), icon: const Icon(Icons.person_add_alt_outlined), label: const Text('Add Doctor')) : null,
      body: PageBody(onRefresh: () async => ref.invalidate(adminDoctorsProvider(key)), children: [
        Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search by name, email or Doctor ID', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => _debouncer(() => setState(() => _query = v.trim())),
            ),
          ),
          Wrap(spacing: AppSpacing.sm, children: [
            for (final s in const {'all': 'All', 'active': 'Active', 'inactive': 'Inactive'}.entries)
              ChoiceChip(label: Text(s.value), selected: _status == s.key, onSelected: (_) => setState(() => _status = s.key)),
          ]),
        ]),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: ref.watch(adminDoctorsProvider(key)),
          onRetry: () => ref.invalidate(adminDoctorsProvider(key)),
          loading: const SkeletonList(count: 5),
          data: (items) => items.isEmpty
              ? EmptyState(icon: Icons.medical_services_outlined, title: 'No doctors found.', actionLabel: 'Add Doctor', onAction: () => context.push('/a/doctors/new'))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Doctors (${items.length})', style: t.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ResponsiveTable<DoctorProfile>(
                    rows: items,
                    onRowTap: (d) => context.push(adminDoctorRoute(d.id)),
                    columns: [
                      TableColumnSpec(
                        'Doctor',
                        (d) => Row(children: [
                          SusthitiAvatar(d.fullName, size: 36),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: CellText('Dr. ${d.fullName}', secondary: d.email, bold: true)),
                          if (d.isDemo) const DemoBadge(),
                        ]),
                        flex: 4,
                      ),
                      TableColumnSpec('Doctor ID', (d) => CellText(d.doctorCode), flex: 3),
                      TableColumnSpec('Specialization', (d) => CellText(d.specialization ?? '—'), flex: 3),
                      TableColumnSpec('Contact', (d) => CellText(d.phone ?? '—'), flex: 2, tabletVisible: false),
                      TableColumnSpec('Patients', (d) => CellText('${d.activePatients ?? 0} active'), flex: 2),
                      TableColumnSpec('Last activity', (d) => CellText(d.lastActivityAt == null ? '—' : Fmt.relative(d.lastActivityAt)), flex: 2, tabletVisible: false),
                      TableColumnSpec('Status', (d) => PillCell(activePill(d.isActive)), flex: 2),
                    ],
                    trailing: (d) => Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(onPressed: () => context.push(adminDoctorRoute(d.id)), child: const Text('View Profile')),
                      _menu(d),
                    ]),
                    mobileCard: (d) => AppCard(
                      onTap: () => context.push(adminDoctorRoute(d.id)),
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
                      child: Row(children: [
                        SusthitiAvatar(d.fullName, size: 44),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Dr. ${d.fullName}', style: t.titleSmall, overflow: TextOverflow.ellipsis),
                            Text([d.doctorCode, ?d.specialization].join(' · '), style: t.bodySmall, overflow: TextOverflow.ellipsis),
                            Text('${d.activePatients ?? 0} active patients · ${lastActive(d)}', style: t.bodySmall, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: AppSpacing.xs),
                            activePill(d.isActive),
                          ]),
                        ),
                        _menu(d),
                      ]),
                    ),
                  ),
                ]),
        ),
      ]),
    );
  }
}

/// Create (doctor == null) or edit/deactivate a doctor. Doctors are only ever created here.
class DoctorFormScreen extends ConsumerStatefulWidget {
  const DoctorFormScreen({super.key, this.doctor});
  final DoctorProfile? doctor;

  @override
  ConsumerState<DoctorFormScreen> createState() => _DoctorFormScreenState();
}

class _DoctorFormScreenState extends ConsumerState<DoctorFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.doctor?.fullName);
  late final _email = TextEditingController(text: widget.doctor?.email);
  late final _specialization = TextEditingController(text: widget.doctor?.specialization);
  late final _license = TextEditingController(text: widget.doctor?.licenseNumber);
  late final _phone = TextEditingController(text: widget.doctor?.phone);
  final _password = TextEditingController();
  late bool _active = widget.doctor?.isActive ?? true;

  bool get _editing => widget.doctor != null;

  @override
  void dispose() {
    for (final c in [_name, _email, _specialization, _license, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(adminRepositoryProvider);
    try {
      if (_editing) {
        await repo.updateDoctor(widget.doctor!.id, {
          'full_name': _name.text.trim(),
          'specialization': _v(_specialization),
          'license_number': _v(_license),
          'phone': _v(_phone),
        });
      } else {
        await repo.createDoctor(fullName: _name.text, email: _email.text, temporaryPassword: _password.text, specialization: _specialization.text, licenseNumber: _license.text, phone: _phone.text);
      }
      ref.invalidate(adminDoctorsProvider);
      if (_editing) ref.invalidate(adminDoctorProvider(widget.doctor!.id));
      if (!mounted) return;
      showToast(context, _editing ? 'Doctor updated' : 'Doctor account created. Share the temporary password securely.');
      context.pop();
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _toggleActive() async {
    final next = !_active;
    if (!next) {
      final ok = await confirmAction(context,
          title: 'Deactivate doctor?', message: 'They will be signed out and cannot sign in. Their past records remain in patient histories.', confirmLabel: 'Deactivate', destructive: true);
      if (!ok) return;
    }
    try {
      await ref.read(adminRepositoryProvider).updateDoctor(widget.doctor!.id, {'is_active': next});
      ref.invalidate(adminDoctorsProvider);
      ref.invalidate(adminDoctorProvider(widget.doctor!.id));
      setState(() => _active = next);
      if (mounted) showToast(context, next ? 'Doctor reactivated' : 'Doctor deactivated');
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: _editing ? 'Edit Doctor' : 'Add Doctor',
      body: PageBody(maxWidth: 600, children: [
        if (_editing) ...[
          AppCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.doctor!.doctorCode, style: t.titleSmall),
                  Text(widget.doctor!.email, style: t.bodySmall),
                  if (widget.doctor!.createdAt != null) Text('Created ${Fmt.date(widget.doctor!.createdAt)}', style: t.bodySmall),
                ]),
              ),
              StatusPill(_active ? 'Active' : 'Inactive', tone: _active ? StatusTone.positive : StatusTone.inactive),
            ]),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppTextField(label: 'Full name', controller: _name, validator: (v) => Validators.required(v, 'Full name'), textCapitalization: TextCapitalization.words),
            if (!_editing) ...[
              AppTextField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress, validator: Validators.email),
              PasswordField(controller: _password, label: 'Temporary password', newPassword: true, validator: Validators.password, helper: 'The doctor should change it after first sign-in.'),
            ],
            AppTextField(label: 'Specialization', controller: _specialization, optional: true, hint: 'e.g. Endocrinology'),
            AppTextField(
              label: 'License / registration number',
              controller: _license,
              validator: (v) => (v ?? '').trim().length < 3 ? 'Enter the doctor\'s license or registration number.' : null,
            ),
            AppTextField(label: 'Phone', controller: _phone, optional: true, keyboardType: TextInputType.phone, validator: Validators.optionalPhone),
            BusyButton(label: _editing ? 'Save changes' : 'Create doctor account', onPressed: _save, expand: true),
            if (_editing) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: _toggleActive,
                style: _active ? OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)) : null,
                child: Text(_active ? 'Deactivate doctor' : 'Reactivate doctor'),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class AdminPatientsScreen extends ConsumerStatefulWidget {
  const AdminPatientsScreen({super.key});

  @override
  ConsumerState<AdminPatientsScreen> createState() => _AdminPatientsScreenState();
}

/// Patient list. A row (or View Profile) opens the complete patient profile; editing is separate.
class _AdminPatientsScreenState extends ConsumerState<AdminPatientsScreen> {
  final _debouncer = Debouncer();
  String _query = '';
  String _status = 'all';

  AdminPatientsKey get _key => (query: _query, status: _status);

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _toggle(AdminPatient p) async {
    if (p.isActive) {
      final ok = await confirmAction(context, title: 'Deactivate ${p.fullName}?', message: 'They will be signed out and cannot sign in. Their records are kept.', confirmLabel: 'Deactivate', destructive: true);
      if (!ok) return;
    }
    try {
      await ref.read(adminRepositoryProvider).setPatientActive(p.id, !p.isActive);
      ref.invalidate(adminPatientsProvider(_key));
      ref.invalidate(adminPatientProvider(p.id));
      if (mounted) showToast(context, p.isActive ? 'Patient deactivated' : 'Patient reactivated');
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  void _action(AdminPatient p, String action) => switch (action) {
        'edit' => context.push('/a/patients/${p.id}/edit'),
        'reports' || 'activity' || 'doctors' => context.push(adminPatientRoute(p.id, tab: action)),
        'upload' => context.push('/a/patients/${p.id}/upload'),
        'toggle' => _toggle(p),
        _ => context.push(adminPatientRoute(p.id)),
      };

  Widget _menu(AdminPatient p) => PopupMenuButton<String>(
        tooltip: 'Actions for ${p.fullName}',
        icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
        onSelected: (a) => _action(p, a),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'view', child: Text('View profile')),
          const PopupMenuItem(value: 'edit', child: Text('Edit patient')),
          const PopupMenuItem(value: 'reports', child: Text('View reports')),
          const PopupMenuItem(value: 'activity', child: Text('View activity')),
          const PopupMenuItem(value: 'doctors', child: Text('View doctors')),
          const PopupMenuItem(value: 'upload', child: Text('Upload report for patient')),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'toggle', child: Text(p.isActive ? 'Deactivate account' : 'Reactivate account', style: TextStyle(color: p.isActive ? AppColors.errorText : null))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    String ageGender(AdminPatient p) {
      final parts = [if (p.age != null) '${p.age}', ?p.gender];
      return parts.isEmpty ? '—' : parts.join(' · ');
    }

    return AppPage(
      title: 'Patients',
      large: true,
      body: PageBody(onRefresh: () async => ref.invalidate(adminPatientsProvider(_key)), children: [
        Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search by name, email or Patient ID', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => _debouncer(() => setState(() => _query = v.trim())),
            ),
          ),
          Wrap(spacing: AppSpacing.sm, children: [
            for (final s in const {'all': 'All', 'active': 'Active', 'inactive': 'Inactive'}.entries)
              ChoiceChip(label: Text(s.value), selected: _status == s.key, onSelected: (_) => setState(() => _status = s.key)),
          ]),
        ]),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: ref.watch(adminPatientsProvider(_key)),
          onRetry: () => ref.invalidate(adminPatientsProvider(_key)),
          loading: const SkeletonList(count: 5),
          data: (r) => r.items.isEmpty
              ? const EmptyState(icon: Icons.people_outline, title: 'No patients found.')
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(r.total > r.items.length ? 'Patients (${r.total}) · showing the ${r.items.length} most recent. Search to find others.' : 'Patients (${r.total})', style: t.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ResponsiveTable<AdminPatient>(
                    rows: r.items,
                    onRowTap: (p) => context.push(adminPatientRoute(p.id)),
                    columns: [
                      TableColumnSpec(
                        'Patient',
                        (p) => Row(children: [
                          SusthitiAvatar(p.fullName, size: 36),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: CellText(p.fullName, secondary: p.email, bold: true)),
                          if (p.isDemo) const DemoBadge(),
                        ]),
                        flex: 4,
                      ),
                      TableColumnSpec('Patient ID', (p) => CellText(p.patientCode), flex: 3),
                      TableColumnSpec('Age / gender', (p) => CellText(ageGender(p)), flex: 2, tabletVisible: false),
                      TableColumnSpec('Diabetes status', (p) => PillCell(diabetesStatusPill(p.latestRiskCategory)), flex: 3),
                      TableColumnSpec('Doctors', (p) => CellText('${p.approvedDoctors}'), flex: 1, tabletVisible: false),
                      TableColumnSpec('Last activity', (p) => CellText(p.lastActivityAt == null ? '—' : Fmt.relative(p.lastActivityAt)), flex: 2),
                      TableColumnSpec('Status', (p) => PillCell(activePill(p.isActive)), flex: 2),
                    ],
                    trailing: (p) => Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(onPressed: () => context.push(adminPatientRoute(p.id)), child: const Text('View Profile')),
                      _menu(p),
                    ]),
                    mobileCard: (p) => AppCard(
                      onTap: () => context.push(adminPatientRoute(p.id)),
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
                      child: Row(children: [
                        SusthitiAvatar(p.fullName, size: 44),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.fullName, style: t.titleSmall, overflow: TextOverflow.ellipsis),
                            Text([p.patientCode, if (p.age != null) '${p.age} yrs', ?p.gender].join(' · '), style: t.bodySmall, overflow: TextOverflow.ellipsis),
                            Text(
                              '${p.approvedDoctors} doctor${p.approvedDoctors == 1 ? '' : 's'} · Last activity ${p.lastActivityAt == null ? '—' : Fmt.relative(p.lastActivityAt)}',
                              style: t.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [diabetesStatusPill(p.latestRiskCategory), activePill(p.isActive)]),
                          ]),
                        ),
                        _menu(p),
                      ]),
                    ),
                  ),
                ]),
        ),
      ]),
    );
  }
}

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  final _debouncer = Debouncer();
  String _query = '';

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'Audit Logs',
      body: PageBody(maxWidth: 900, onRefresh: () async => ref.invalidate(auditLogsProvider(_query)), children: [
        TextField(
          decoration: const InputDecoration(hintText: 'Search by action, person or reference', prefixIcon: Icon(Icons.search)),
          onChanged: (v) => _debouncer(() => setState(() => _query = v.trim())),
        ),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: ref.watch(auditLogsProvider(_query)),
          onRetry: () => ref.invalidate(auditLogsProvider(_query)),
          data: (r) => r.items.isEmpty
              ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No audit entries.')
              : AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < r.items.length; i++) ...[
                      if (i > 0) const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(Fmt.titleCase(r.items[i].action), style: t.titleSmall),
                              Text(
                                [
                                  if (r.items[i].actorName != null) '${r.items[i].actorName} (${r.items[i].actorRole ?? 'system'})',
                                  ?r.items[i].entityLabel,
                                  if (r.items[i].details['patient_code'] != null) '${r.items[i].details['patient_code']}',
                                ].join(' · '),
                                style: t.bodySmall,
                              ),
                            ]),
                          ),
                          Text(Fmt.dateTime(r.items[i].createdAt), style: t.labelSmall),
                        ]),
                      ),
                    ],
                  ]),
                ),
        ),
      ]),
    );
  }
}

class SystemSettingsScreen extends ConsumerStatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  ConsumerState<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends ConsumerState<SystemSettingsScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};

  static const _labels = {
    'support_email': ('Support email', 'Shown to users who need help.'),
    'max_upload_mb_display': ('Upload limit shown to users (MB)', 'Display only. The enforced limit is set on the server.'),
    'maintenance_notice': ('Maintenance notice', 'Optional banner text.'),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      await ref.read(adminRepositoryProvider).updateSettings({for (final e in _controllers.entries) e.key: e.value.text.trim()});
      ref.invalidate(systemSettingsProvider);
      if (mounted) showToast(context, 'Settings saved');
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'System Settings',
      body: PageBody(maxWidth: 700, children: [
        AsyncBody(
          value: ref.watch(systemSettingsProvider),
          onRetry: () => ref.invalidate(systemSettingsProvider),
          data: (s) {
            for (final e in s.values.entries) {
              _controllers.putIfAbsent(e.key, () => TextEditingController(text: e.value));
            }
            bool on(String k) => s.status[k] == true;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionHeader('Service status', subtitle: 'Secrets are configured on the server and are never shown here.'),
              AppCard(
                child: Column(children: [
                  KeyValueRow('Environment', '${s.status['environment'] ?? '—'}'),
                  KeyValueRow('AI (Google AI Studio)', on('ai_configured') ? 'Configured · ${s.status['ai_model']}' : 'Not configured',
                      trailing: StatusPill(on('ai_configured') ? 'On' : 'Off', tone: on('ai_configured') ? StatusTone.positive : StatusTone.inactive)),
                  KeyValueRow('Diabetes model service', on('ml_service_url_configured') ? 'URL configured' : 'Not configured',
                      trailing: StatusPill(on('ml_service_url_configured') ? 'On' : 'Off', tone: on('ml_service_url_configured') ? StatusTone.positive : StatusTone.inactive)),
                  KeyValueRow('Demo wearable', on('demo_wearable_enabled') ? 'Enabled (data labelled DEMO)' : 'Disabled'),
                ]),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader('Editable settings'),
              Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final key in _controllers.keys)
                    AppTextField(
                      label: _labels[key]?.$1 ?? Fmt.titleCase(key),
                      helper: _labels[key]?.$2,
                      controller: _controllers[key],
                      optional: true,
                      keyboardType: key == 'max_upload_mb_display' ? TextInputType.number : null,
                      validator: switch (key) {
                        'support_email' => (v) => (v == null || v.trim().isEmpty) ? null : Validators.email(v),
                        'max_upload_mb_display' => (v) => (v == null || v.trim().isEmpty) ? null : Validators.numberInRange(v, 1, 100),
                        _ => null,
                      },
                    ),
                  BusyButton(label: 'Save settings', onPressed: _save, expand: true),
                ]),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Changes are recorded in the audit log.', style: t.bodySmall),
            ]);
          },
        ),
      ]),
    );
  }
}

/// Admin "More" tab: audit, system settings and account.
class AdminMoreScreen extends ConsumerWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'More',
      large: true,
      body: PageBody(maxWidth: 700, children: [
        if (user != null) ...[
          Text(user.fullName, style: t.titleMedium),
          Text('${user.email} · Administrator', style: t.bodySmall),
          const SizedBox(height: AppSpacing.lg),
        ],
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primary), title: const Text('Audit logs'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/a/audit')),
            const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            ListTile(leading: const Icon(Icons.tune, color: AppColors.primary), title: const Text('System settings'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/a/system')),
            const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            ListTile(leading: const Icon(Icons.manage_accounts_outlined, color: AppColors.primary), title: const Text('Account and password'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/a/account')),
          ]),
        ),
      ]),
    );
  }
}

/// /a/doctors/:id/edit: load the doctor, then show the edit form.
class EditDoctorLoader extends ConsumerWidget {
  const EditDoctorLoader({super.key, required this.doctorId});
  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(adminDoctorProvider(doctorId)).when(
          data: (d) => DoctorFormScreen(doctor: d.profile),
          loading: () => const AppPage(title: 'Edit Doctor', body: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: SkeletonList(count: 3))),
          error: (e, _) => AppPage(title: 'Edit Doctor', body: ErrorState(error: e, onRetry: () => ref.invalidate(adminDoctorProvider(doctorId)))),
        );
  }
}
