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
import '../../l10n/app_localizations.dart';
import '../authentication/auth_controller.dart';
import 'admin_common.dart';

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboard>((ref) => ref.watch(adminRepositoryProvider).dashboard());

typedef AdminListKey = ({String query, String status});
final adminDoctorsProvider = FutureProvider.autoDispose.family<List<DoctorProfile>, AdminListKey>((ref, k) => ref.watch(adminRepositoryProvider).doctors(query: k.query, status: k.status));
typedef AdminPatientsKey = ({String query, String status});
final adminPatientsProvider =
    FutureProvider.autoDispose.family<({List<AdminPatient> items, int total}), AdminPatientsKey>((ref, k) => ref.watch(adminRepositoryProvider).patients(query: k.query, status: k.status));
final auditLogsProvider = FutureProvider.autoDispose.family<({List<AuditEntry> items, int total}), String>((ref, q) => ref.watch(adminRepositoryProvider).auditLogs(query: q));
final notificationDeliveryProvider =
    FutureProvider.autoDispose.family<({List<NotificationDeliveryEntry> items, int total}), String?>((ref, status) => ref.watch(adminRepositoryProvider).notificationDelivery(status: status));
final systemSettingsProvider = FutureProvider.autoDispose<SystemSettings>((ref) => ref.watch(adminRepositoryProvider).settings());

/// Admins manage accounts and access, and can open any doctor's or patient's complete record
/// (read-only) from the lists.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: l10n.adminDashboardTitle,
      large: true,
      brand: true,
      body: PageBody(onRefresh: () async => ref.invalidate(adminDashboardProvider), children: [
        AsyncBody(
          value: ref.watch(adminDashboardProvider),
          onRetry: () => ref.invalidate(adminDashboardProvider),
          data: (d) {
            int m(String k) => d.metrics[k] ?? 0;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ResponsiveGrid(minItemWidth: 170, maxColumns: 5, children: [
                MetricTile(icon: Icons.medical_services_outlined, label: l10n.navDoctors, value: '${m('total_doctors')}', caption: l10n.adminActiveCountCaption('${m('active_doctors')}'), onTap: () => context.go('/a/doctors')),
                MetricTile(icon: Icons.people_outline, label: l10n.navPatients, value: '${m('total_patients')}', caption: l10n.adminRegisteredCaption, onTap: () => context.go('/a/patients')),
                MetricTile(icon: Icons.person_pin_outlined, label: l10n.adminActivePatientsLabel, value: '${m('active_patients')}', caption: l10n.adminLast30DaysCaption),
                MetricTile(icon: Icons.hourglass_empty, label: l10n.docPendingRequests, value: '${m('pending_requests')}', caption: l10n.adminDoctorAccessCaption, onTap: () => context.go('/a/access')),
              ]),
              const SizedBox(height: AppSpacing.section),
              SectionHeader(l10n.adminOperationalOverviewHeader, subtitle: l10n.adminOperationalOverviewSubtitle),
              ResponsiveGrid(minItemWidth: 170, maxColumns: 5, children: [
                MetricTile(icon: Icons.event_available_outlined, label: l10n.navAppointments, value: '${m('appointments_7d')}', caption: l10n.docAppointmentsCaption),
                MetricTile(icon: Icons.event_repeat_outlined, label: l10n.navFollowUps, value: '${m('follow_ups_scheduled')}', caption: l10n.commonScheduledCaption),
                MetricTile(icon: Icons.local_hospital_outlined, label: l10n.navSurgeries, value: '${m('surgeries_scheduled')}', caption: l10n.commonScheduledCaption),
                MetricTile(icon: Icons.description_outlined, label: l10n.navReports, value: '${m('reports_7d')}', caption: l10n.adminUploadedLast7Days),
                MetricTile(
                  icon: Icons.notifications_off_outlined,
                  label: l10n.adminFailedPushesLabel,
                  value: '${m('failed_push_notifications_7d')}',
                  caption: l10n.docNewReportsCaption,
                  onTap: () => context.push('/a/notifications'),
                ),
              ]),
              const SizedBox(height: AppSpacing.section),
              SectionHeader(l10n.docQuickActions),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                FilledButton.icon(onPressed: () => context.push('/a/doctors/new'), icon: const Icon(Icons.person_add_alt_outlined), label: Text(l10n.adminAddDoctorButton)),
                OutlinedButton.icon(onPressed: () => context.push('/a/audit'), icon: const Icon(Icons.receipt_long_outlined), label: Text(l10n.adminAuditLogsTitle)),
                OutlinedButton.icon(onPressed: () => context.push('/a/system'), icon: const Icon(Icons.tune), label: Text(l10n.adminSystemSettingsTitle)),
              ]),
              const SizedBox(height: AppSpacing.section),
              SectionHeader(l10n.docRecentActivity, action: TextButton(onPressed: () => context.push('/a/audit'), child: Text(l10n.commonViewAll))),
              AppCard(
                child: d.recentActivity.isEmpty
                    ? Text(l10n.adminNoActivityYetDot, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        for (final a in d.recentActivity)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.sentence, style: t.bodyMedium), Text(Fmt.relative(l10n, a.createdAt), style: t.bodySmall)]),
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

  Future<void> _toggle(DoctorProfile d, AppLocalizations l10n) async {
    if (d.isActive) {
      final ok = await confirmAction(context,
          title: l10n.adminDeactivateDoctorTitle(d.fullName), message: l10n.adminDeactivateDoctorMessage, confirmLabel: l10n.commonDeactivate, destructive: true);
      if (!ok) return;
    }
    try {
      await ref.read(adminRepositoryProvider).updateDoctor(d.id, {'is_active': !d.isActive});
      ref.invalidate(adminDoctorsProvider);
      ref.invalidate(adminDoctorProvider(d.id));
      if (mounted) showToast(context, d.isActive ? l10n.adminDoctorDeactivatedToast : l10n.adminDoctorReactivatedToast);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  void _action(DoctorProfile d, String action, AppLocalizations l10n) => switch (action) {
        'edit' => context.push('/a/doctors/${d.id}/edit'),
        'patients' => context.push(adminDoctorRoute(d.id, tab: 'patients')),
        'activity' => context.push(adminDoctorRoute(d.id, tab: 'activity')),
        'toggle' => _toggle(d, l10n),
        _ => context.push(adminDoctorRoute(d.id)),
      };

  Widget _menu(DoctorProfile d, AppLocalizations l10n) => PopupMenuButton<String>(
        tooltip: l10n.adminActionsForDoctorTooltip(d.fullName),
        icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
        onSelected: (a) => _action(d, a, l10n),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'view', child: Text(l10n.commonViewProfile)),
          PopupMenuItem(value: 'edit', child: Text(l10n.adminEditDoctorMenuItem)),
          PopupMenuItem(value: 'patients', child: Text(l10n.adminViewPatientsMenuItem)),
          PopupMenuItem(value: 'activity', child: Text(l10n.commonViewActivity)),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'toggle', child: Text(d.isActive ? l10n.commonDeactivate : l10n.commonReactivate, style: TextStyle(color: d.isActive ? AppColors.errorText : null))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final key = (query: _query, status: _status);
    final t = Theme.of(context).textTheme;
    final mobile = context.screenSize == ScreenSize.mobile;
    String lastActive(DoctorProfile d) => d.lastActivityAt == null ? l10n.adminNoActivityShort : l10n.adminLastActiveLabel(Fmt.relative(l10n, d.lastActivityAt));
    return AppPage(
      title: l10n.navDoctors,
      large: true,
      actions: [
        if (!mobile) FilledButton.icon(onPressed: () => context.push('/a/doctors/new'), icon: const Icon(Icons.person_add_alt_outlined, size: 18), label: Text(l10n.adminAddDoctorButton)),
      ],
      floatingActionButton: mobile ? FloatingActionButton.extended(onPressed: () => context.push('/a/doctors/new'), icon: const Icon(Icons.person_add_alt_outlined), label: Text(l10n.adminAddDoctorButton)) : null,
      body: PageBody(onRefresh: () async => ref.invalidate(adminDoctorsProvider(key)), children: [
        Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: TextField(
              decoration: InputDecoration(hintText: l10n.adminDoctorSearchHint, prefixIcon: const Icon(Icons.search)),
              onChanged: (v) => _debouncer(() => setState(() => _query = v.trim())),
            ),
          ),
          Wrap(spacing: AppSpacing.sm, children: [
            for (final s in {'all': l10n.notifFilterAll, 'active': l10n.commonActive, 'inactive': l10n.commonInactive}.entries)
              ChoiceChip(label: Text(s.value), selected: _status == s.key, onSelected: (_) => setState(() => _status = s.key)),
          ]),
        ]),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: ref.watch(adminDoctorsProvider(key)),
          onRetry: () => ref.invalidate(adminDoctorsProvider(key)),
          loading: const SkeletonList(count: 5),
          data: (items) => items.isEmpty
              ? EmptyState(icon: Icons.medical_services_outlined, title: l10n.adminNoDoctorsFound, actionLabel: l10n.adminAddDoctorButton, onAction: () => context.push('/a/doctors/new'))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(l10n.adminDoctorsCountHeader(items.length), style: t.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ResponsiveTable<DoctorProfile>(
                    rows: items,
                    onRowTap: (d) => context.push(adminDoctorRoute(d.id)),
                    columns: [
                      TableColumnSpec(
                        l10n.adminColDoctor,
                        (d) => Row(children: [
                          SusthitiAvatar(d.fullName, size: 36),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: CellText(l10n.commonDrName(d.fullName), secondary: d.email, bold: true)),
                          if (d.isDemo) const DemoBadge(),
                        ]),
                        flex: 4,
                      ),
                      TableColumnSpec(l10n.adminColDoctorId, (d) => CellText(d.doctorCode), flex: 3),
                      TableColumnSpec(l10n.commonSpecializationLabel, (d) => CellText(d.specialization ?? '—'), flex: 3),
                      TableColumnSpec(l10n.commonContactHeader, (d) => CellText(d.phone ?? '—'), flex: 2, tabletVisible: false),
                      TableColumnSpec(l10n.adminColPatients, (d) => CellText(l10n.adminActiveCountCaption('${d.activePatients ?? 0}')), flex: 2),
                      TableColumnSpec(l10n.adminColLastActivity, (d) => CellText(d.lastActivityAt == null ? '—' : Fmt.relative(l10n, d.lastActivityAt)), flex: 2, tabletVisible: false),
                      TableColumnSpec(l10n.adminColStatus, (d) => PillCell(activePill(l10n, d.isActive)), flex: 2),
                    ],
                    trailing: (d) => Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(onPressed: () => context.push(adminDoctorRoute(d.id)), child: Text(l10n.commonViewProfileButton)),
                      _menu(d, l10n),
                    ]),
                    mobileCard: (d) => AppCard(
                      onTap: () => context.push(adminDoctorRoute(d.id)),
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
                      child: Row(children: [
                        SusthitiAvatar(d.fullName, size: 44),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l10n.commonDrName(d.fullName), style: t.titleSmall, overflow: TextOverflow.ellipsis),
                            Text([d.doctorCode, ?d.specialization].join(' · '), style: t.bodySmall, overflow: TextOverflow.ellipsis),
                            Text(l10n.adminDoctorRowCaption(d.activePatients ?? 0, lastActive(d)), style: t.bodySmall, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: AppSpacing.xs),
                            activePill(l10n, d.isActive),
                          ]),
                        ),
                        _menu(d, l10n),
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

  Future<void> _save(AppLocalizations l10n) async {
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
      showToast(context, _editing ? l10n.adminDoctorUpdatedToast : l10n.adminDoctorCreatedToast);
      context.pop();
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _toggleActive(AppLocalizations l10n) async {
    final next = !_active;
    if (!next) {
      final ok = await confirmAction(context,
          title: l10n.adminDeactivateDoctorConfirmTitle, message: l10n.adminDeactivateDoctorMessage, confirmLabel: l10n.commonDeactivate, destructive: true);
      if (!ok) return;
    }
    try {
      await ref.read(adminRepositoryProvider).updateDoctor(widget.doctor!.id, {'is_active': next});
      ref.invalidate(adminDoctorsProvider);
      ref.invalidate(adminDoctorProvider(widget.doctor!.id));
      setState(() => _active = next);
      if (mounted) showToast(context, next ? l10n.adminDoctorReactivatedToast : l10n.adminDoctorDeactivatedToast);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: _editing ? l10n.adminEditDoctorTitle : l10n.adminAddDoctorButton,
      body: PageBody(maxWidth: 600, children: [
        if (_editing) ...[
          AppCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.doctor!.doctorCode, style: t.titleSmall),
                  Text(widget.doctor!.email, style: t.bodySmall),
                  if (widget.doctor!.createdAt != null) Text(l10n.commonCreatedOn(Fmt.date(widget.doctor!.createdAt)), style: t.bodySmall),
                ]),
              ),
              StatusPill(_active ? l10n.commonActive : l10n.commonInactive, tone: _active ? StatusTone.positive : StatusTone.inactive),
            ]),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppTextField(label: l10n.authFullName, controller: _name, validator: (v) => Validators.required(l10n, v, l10n.authFullName), textCapitalization: TextCapitalization.words),
            if (!_editing) ...[
              AppTextField(label: l10n.authEmailLabel, controller: _email, keyboardType: TextInputType.emailAddress, validator: (v) => Validators.email(l10n, v)),
              PasswordField(controller: _password, label: l10n.adminTemporaryPasswordLabel, newPassword: true, validator: (v) => Validators.password(l10n, v), helper: l10n.adminTempPasswordHelper),
            ],
            AppTextField(label: l10n.commonSpecializationLabel, controller: _specialization, optional: true, hint: l10n.adminSpecializationHint),
            AppTextField(
              label: l10n.adminLicenseNumberLabel,
              controller: _license,
              validator: (v) => (v ?? '').trim().length < 3 ? l10n.adminLicenseValidation : null,
            ),
            AppTextField(label: l10n.authPhone, controller: _phone, optional: true, keyboardType: TextInputType.phone, validator: (v) => Validators.optionalPhone(l10n, v)),
            BusyButton(label: _editing ? l10n.commonSaveChanges : l10n.adminCreateDoctorAccountButton, onPressed: () => _save(l10n), expand: true),
            if (_editing) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => _toggleActive(l10n),
                style: _active ? OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)) : null,
                child: Text(_active ? l10n.adminDeactivateDoctorButton : l10n.adminReactivateDoctorButton),
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

  Future<void> _toggle(AdminPatient p, AppLocalizations l10n) async {
    if (p.isActive) {
      final ok = await confirmAction(context, title: l10n.adminDeactivatePatientTitle(p.fullName), message: l10n.adminDeactivatePatientMessage, confirmLabel: l10n.commonDeactivate, destructive: true);
      if (!ok) return;
    }
    try {
      await ref.read(adminRepositoryProvider).setPatientActive(p.id, !p.isActive);
      ref.invalidate(adminPatientsProvider(_key));
      ref.invalidate(adminPatientProvider(p.id));
      if (mounted) showToast(context, p.isActive ? l10n.adminPatientDeactivatedToast : l10n.adminPatientReactivatedToast);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  void _action(AdminPatient p, String action, AppLocalizations l10n) => switch (action) {
        'edit' => context.push('/a/patients/${p.id}/edit'),
        'reports' || 'activity' || 'doctors' => context.push(adminPatientRoute(p.id, tab: action)),
        'upload' => context.push('/a/patients/${p.id}/upload'),
        'toggle' => _toggle(p, l10n),
        _ => context.push(adminPatientRoute(p.id)),
      };

  Widget _menu(AdminPatient p, AppLocalizations l10n) => PopupMenuButton<String>(
        tooltip: l10n.adminActionsForPatientTooltip(p.fullName),
        icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
        onSelected: (a) => _action(p, a, l10n),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'view', child: Text(l10n.commonViewProfile)),
          PopupMenuItem(value: 'edit', child: Text(l10n.adminEditPatientMenuItem)),
          PopupMenuItem(value: 'reports', child: Text(l10n.adminViewReportsMenuItem)),
          PopupMenuItem(value: 'activity', child: Text(l10n.commonViewActivity)),
          PopupMenuItem(value: 'doctors', child: Text(l10n.adminViewDoctorsMenuItem)),
          PopupMenuItem(value: 'upload', child: Text(l10n.adminUploadReportForPatientMenuItem)),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'toggle', child: Text(p.isActive ? l10n.adminDeactivateAccountMenuItem : l10n.adminReactivateAccountMenuItem, style: TextStyle(color: p.isActive ? AppColors.errorText : null))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    String ageGender(AdminPatient p) {
      final parts = [if (p.age != null) '${p.age}', ?p.gender];
      return parts.isEmpty ? '—' : parts.join(' · ');
    }

    return AppPage(
      title: l10n.navPatients,
      large: true,
      body: PageBody(onRefresh: () async => ref.invalidate(adminPatientsProvider(_key)), children: [
        Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: TextField(
              decoration: InputDecoration(hintText: l10n.adminPatientSearchHint, prefixIcon: const Icon(Icons.search)),
              onChanged: (v) => _debouncer(() => setState(() => _query = v.trim())),
            ),
          ),
          Wrap(spacing: AppSpacing.sm, children: [
            for (final s in {'all': l10n.notifFilterAll, 'active': l10n.commonActive, 'inactive': l10n.commonInactive}.entries)
              ChoiceChip(label: Text(s.value), selected: _status == s.key, onSelected: (_) => setState(() => _status = s.key)),
          ]),
        ]),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: ref.watch(adminPatientsProvider(_key)),
          onRetry: () => ref.invalidate(adminPatientsProvider(_key)),
          loading: const SkeletonList(count: 5),
          data: (r) => r.items.isEmpty
              ? EmptyState(icon: Icons.people_outline, title: l10n.adminNoPatientsFound)
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(r.total > r.items.length ? l10n.adminPatientsCountShowing(r.total, r.items.length) : l10n.adminPatientsCountHeader(r.total), style: t.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ResponsiveTable<AdminPatient>(
                    rows: r.items,
                    onRowTap: (p) => context.push(adminPatientRoute(p.id)),
                    columns: [
                      TableColumnSpec(
                        l10n.adminColPatient,
                        (p) => Row(children: [
                          SusthitiAvatar(p.fullName, size: 36),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: CellText(p.fullName, secondary: p.email, bold: true)),
                          if (p.isDemo) const DemoBadge(),
                        ]),
                        flex: 4,
                      ),
                      TableColumnSpec(l10n.doctorPatientIdLabel, (p) => CellText(p.patientCode), flex: 3),
                      TableColumnSpec(l10n.adminColAgeGender, (p) => CellText(ageGender(p)), flex: 2, tabletVisible: false),
                      TableColumnSpec(l10n.adminColDiabetesStatus, (p) => PillCell(diabetesStatusPill(l10n, p.latestRiskCategory)), flex: 3),
                      TableColumnSpec(l10n.navDoctors, (p) => CellText('${p.approvedDoctors}'), flex: 1, tabletVisible: false),
                      TableColumnSpec(l10n.adminColLastActivity, (p) => CellText(p.lastActivityAt == null ? '—' : Fmt.relative(l10n, p.lastActivityAt)), flex: 2),
                      TableColumnSpec(l10n.adminColStatus, (p) => PillCell(activePill(l10n, p.isActive)), flex: 2),
                    ],
                    trailing: (p) => Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(onPressed: () => context.push(adminPatientRoute(p.id)), child: Text(l10n.commonViewProfileButton)),
                      _menu(p, l10n),
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
                              l10n.adminPatientRowCaption(p.approvedDoctors, p.lastActivityAt == null ? '—' : Fmt.relative(l10n, p.lastActivityAt)),
                              style: t.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [diabetesStatusPill(l10n, p.latestRiskCategory), activePill(l10n, p.isActive)]),
                          ]),
                        ),
                        _menu(p, l10n),
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
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: l10n.adminAuditLogsTitle,
      body: PageBody(maxWidth: 900, onRefresh: () async => ref.invalidate(auditLogsProvider(_query)), children: [
        TextField(
          decoration: InputDecoration(hintText: l10n.adminAuditSearchHint, prefixIcon: const Icon(Icons.search)),
          onChanged: (v) => _debouncer(() => setState(() => _query = v.trim())),
        ),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: ref.watch(auditLogsProvider(_query)),
          onRetry: () => ref.invalidate(auditLogsProvider(_query)),
          data: (r) => r.items.isEmpty
              ? EmptyState(icon: Icons.receipt_long_outlined, title: l10n.adminNoAuditEntries)
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
                              Text(auditActionText(l10n, r.items[i].action), style: t.titleSmall),
                              Text(
                                [
                                  if (r.items[i].actorName != null) '${r.items[i].actorName} (${r.items[i].actorRole ?? l10n.adminSystemRoleFallback})',
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

/// Delivery status only — type, recipient role, outcome. Never a notification's title or
/// body; those are free text that can name a patient and have no operational reason to be here.
class NotificationDeliveryScreen extends ConsumerStatefulWidget {
  const NotificationDeliveryScreen({super.key});

  @override
  ConsumerState<NotificationDeliveryScreen> createState() => _NotificationDeliveryScreenState();
}

class _NotificationDeliveryScreenState extends ConsumerState<NotificationDeliveryScreen> {
  String? _status;

  static StatusTone _tone(String? status) => switch (status) {
        'sent' => StatusTone.positive,
        'failed' => StatusTone.critical,
        _ => StatusTone.inactive,
      };

  static String _label(AppLocalizations l10n, String? status) => switch (status) { 'sent' => l10n.adminPushSent, 'failed' => l10n.adminPushFailed, _ => l10n.adminPushNotAttempted };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: l10n.navNotificationDelivery,
      body: PageBody(maxWidth: 900, onRefresh: () async => ref.invalidate(notificationDeliveryProvider(_status)), children: [
        Text(l10n.adminPushStatusOnlyNote, style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        Wrap(spacing: AppSpacing.sm, children: [
          ChoiceChip(label: Text(l10n.notifFilterAll), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
          ChoiceChip(label: Text(l10n.adminPushSent), selected: _status == 'sent', onSelected: (_) => setState(() => _status = 'sent')),
          ChoiceChip(label: Text(l10n.adminPushFailed), selected: _status == 'failed', onSelected: (_) => setState(() => _status = 'failed')),
          ChoiceChip(label: Text(l10n.adminPushNotAttempted), selected: _status == 'none', onSelected: (_) => setState(() => _status = 'none')),
        ]),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: ref.watch(notificationDeliveryProvider(_status)),
          onRetry: () => ref.invalidate(notificationDeliveryProvider(_status)),
          data: (r) => r.items.isEmpty
              ? EmptyState(icon: Icons.notifications_none_outlined, title: l10n.adminNoNotificationsMatchFilter)
              : AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < r.items.length; i++) ...[
                      if (i > 0) const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(Fmt.titleCase(r.items[i].type), style: t.titleSmall),
                              Text(r.items[i].recipientRole ?? l10n.adminUnknownRecipient, style: t.bodySmall),
                            ]),
                          ),
                          StatusPill(_label(l10n, r.items[i].pushStatus), tone: _tone(r.items[i].pushStatus)),
                          const SizedBox(width: AppSpacing.md),
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

  static Map<String, (String, String)> _labels(AppLocalizations l10n) => {
        'support_email': (l10n.adminSupportEmailLabel, l10n.adminSupportEmailHelper),
        'max_upload_mb_display': (l10n.adminUploadLimitLabel, l10n.adminUploadLimitHelper),
        'maintenance_notice': (l10n.adminMaintenanceNoticeLabel, l10n.adminMaintenanceNoticeHelper),
      };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(AppLocalizations l10n) async {
    if (!_form.currentState!.validate()) return;
    try {
      await ref.read(adminRepositoryProvider).updateSettings({for (final e in _controllers.entries) e.key: e.value.text.trim()});
      ref.invalidate(systemSettingsProvider);
      if (mounted) showToast(context, l10n.adminSettingsSavedToast);
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final labels = _labels(l10n);
    return AppPage(
      title: l10n.adminSystemSettingsTitle,
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
              SectionHeader(l10n.adminServiceStatusHeader, subtitle: l10n.adminServiceStatusSubtitle),
              AppCard(
                child: Column(children: [
                  KeyValueRow(l10n.adminEnvironmentLabel, '${s.status['environment'] ?? '—'}'),
                  KeyValueRow(l10n.adminAiServiceLabel, on('ai_configured') ? l10n.adminConfiguredWithModel('${s.status['ai_model']}') : l10n.commonNotConfigured,
                      trailing: StatusPill(on('ai_configured') ? l10n.commonOn : l10n.commonOff, tone: on('ai_configured') ? StatusTone.positive : StatusTone.inactive)),
                  KeyValueRow(l10n.adminDiabetesModelServiceLabel, on('ml_service_url_configured') ? l10n.adminUrlConfigured : l10n.commonNotConfigured,
                      trailing: StatusPill(on('ml_service_url_configured') ? l10n.commonOn : l10n.commonOff, tone: on('ml_service_url_configured') ? StatusTone.positive : StatusTone.inactive)),
                  KeyValueRow(l10n.adminDemoWearableLabel, on('demo_wearable_enabled') ? l10n.adminDemoWearableEnabled : l10n.commonDisabled),
                ]),
              ),
              const SizedBox(height: AppSpacing.section),
              SectionHeader(l10n.adminEditableSettingsHeader),
              Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final key in _controllers.keys)
                    AppTextField(
                      label: labels[key]?.$1 ?? Fmt.titleCase(key),
                      helper: labels[key]?.$2,
                      controller: _controllers[key],
                      optional: true,
                      keyboardType: key == 'max_upload_mb_display' ? TextInputType.number : null,
                      validator: switch (key) {
                        'support_email' => (v) => (v == null || v.trim().isEmpty) ? null : Validators.email(l10n, v),
                        'max_upload_mb_display' => (v) => (v == null || v.trim().isEmpty) ? null : Validators.numberInRange(l10n, v, 1, 100),
                        _ => null,
                      },
                    ),
                  BusyButton(label: l10n.adminSaveSettingsButton, onPressed: () => _save(l10n), expand: true),
                ]),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.adminChangesRecordedNote, style: t.bodySmall),
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
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: l10n.navMore,
      large: true,
      body: PageBody(maxWidth: 700, children: [
        if (user != null) ...[
          Text(user.fullName, style: t.titleMedium),
          Text(l10n.adminEmailAdministratorLine(user.email), style: t.bodySmall),
          const SizedBox(height: AppSpacing.lg),
        ],
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primary), title: Text(l10n.adminAuditLogsTitle), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/a/audit')),
            const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            ListTile(leading: const Icon(Icons.tune, color: AppColors.primary), title: Text(l10n.adminSystemSettingsTitle), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/a/system')),
            const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            ListTile(leading: const Icon(Icons.manage_accounts_outlined, color: AppColors.primary), title: Text(l10n.adminAccountAndPasswordLabel), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/a/account')),
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
    final l10n = AppLocalizations.of(context);
    return ref.watch(adminDoctorProvider(doctorId)).when(
          data: (d) => DoctorFormScreen(doctor: d.profile),
          loading: () => AppPage(title: l10n.adminEditDoctorTitle, body: const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: SkeletonList(count: 3))),
          error: (e, _) => AppPage(title: l10n.adminEditDoctorTitle, body: ErrorState(error: e, onRetry: () => ref.invalidate(adminDoctorProvider(doctorId)))),
        );
  }
}
