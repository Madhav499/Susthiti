import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/patient.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../authentication/auth_controller.dart';

final accessRequestsProvider = FutureProvider.autoDispose.family<List<AccessRequest>, UserRole>((ref, role) {
  return switch (role) {
    UserRole.patient => ref.watch(patientRepositoryProvider).accessRequests(),
    UserRole.doctor => ref.watch(doctorRepositoryProvider).accessRequests(),
    UserRole.admin => ref.watch(adminRepositoryProvider).accessRequests(),
  };
});

extension AccessStatusTone on AccessStatus {
  StatusTone get tone => switch (this) {
        AccessStatus.pending => StatusTone.attention,
        AccessStatus.approved => StatusTone.positive,
        AccessStatus.rejected => StatusTone.inactive,
        AccessStatus.revoked => StatusTone.inactive,
      };
}

/// One screen, three perspectives. Patients approve / reject / revoke; doctors see the state of
/// their requests; admins review all requests and can revoke.
class AccessRequestsScreen extends ConsumerStatefulWidget {
  const AccessRequestsScreen({super.key, this.large = false});
  final bool large;

  @override
  ConsumerState<AccessRequestsScreen> createState() => _AccessRequestsScreenState();
}

class _AccessRequestsScreenState extends ConsumerState<AccessRequestsScreen> {
  AccessStatus? _filter;

  UserRole get _role => ref.read(currentUserProvider)?.role ?? UserRole.patient;

  Future<void> _act(AccessRequest r, String action) async {
    final role = _role;
    final l10n = AppLocalizations.of(context);
    if (action != 'approve') {
      final ok = await confirmAction(
        context,
        title: switch (action) { 'reject' => l10n.accessRejectConfirmTitle, _ => l10n.accessRevokeConfirmTitle },
        message: switch (action) {
          'reject' => l10n.accessRejectConfirmMessage(r.doctorName),
          _ => role == UserRole.admin
              ? l10n.accessRevokeConfirmMessageAdmin(r.doctorName, r.patientName)
              : l10n.accessRevokeConfirmMessagePatient(r.doctorName),
        },
        confirmLabel: action == 'reject' ? l10n.accessRejectButton : l10n.accessRevokeButton,
        destructive: true,
      );
      if (!ok) return;
    }
    try {
      switch ((role, action)) {
        case (UserRole.admin, _):
          await ref.read(adminRepositoryProvider).revokeAccess(r.id);
        case (_, 'revoke'):
          await ref.read(patientRepositoryProvider).revokeAccess(r.id);
        default:
          await ref.read(patientRepositoryProvider).respondToAccess(r.id, approve: action == 'approve');
      }
      ref.invalidate(accessRequestsProvider(role));
      if (mounted) showToast(context, switch (action) { 'approve' => l10n.accessApprovedToast, 'reject' => l10n.accessRejectedToast, _ => l10n.accessRevokedToast });
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserProvider)?.role ?? UserRole.patient;
    final value = ref.watch(accessRequestsProvider(role));
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: switch (role) { UserRole.patient => l10n.accessPatientPageTitle, UserRole.doctor => l10n.docAccessRequests, UserRole.admin => l10n.accessAdminPageTitle },
      large: widget.large,
      body: PageBody(
        maxWidth: 820,
        onRefresh: () async => ref.invalidate(accessRequestsProvider(role)),
        children: [
          if (role == UserRole.patient) ...[
            Text(l10n.accessPatientIntro, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final s in <AccessStatus?>[null, ...AccessStatus.values])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(label: Text(s == null ? l10n.accessAllFilterLabel : accessStatusLabel(l10n, s)), selected: _filter == s, onSelected: (_) => setState(() => _filter = s)),
                ),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          AsyncBody(
            value: value,
            onRetry: () => ref.invalidate(accessRequestsProvider(role)),
            data: (all) {
              final items = _filter == null ? all : all.where((r) => r.status == _filter).toList();
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.verified_user_outlined,
                  title: _filter == null ? l10n.accessNoRequestsTitle : l10n.accessNoStatusRequestsTitle(accessStatusLabel(l10n, _filter!).toLowerCase()),
                  message: role == UserRole.patient && _filter == null ? l10n.accessPatientEmptyHint : null,
                );
              }
              return Column(children: [
                for (final r in items) ...[
                  _RequestCard(request: r, role: role, onAction: (a) => _act(r, a)),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ]);
            },
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.role, required this.onAction});
  final AccessRequest request;
  final UserRole role;
  final Future<void> Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final r = request;
    final showDoctor = role != UserRole.doctor;
    final showPatient = role != UserRole.patient;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconBadge(showDoctor ? Icons.medical_services_outlined : Icons.person_outline, tone: r.status.tone),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (showDoctor) Text(l10n.accessDoctorNameLabel(r.doctorName), style: t.titleSmall),
              if (showDoctor && (r.doctorSpecialization != null || r.doctorCode.isNotEmpty))
                Text([
                  if (r.doctorSpecialization != null) l10n.accessSpecializationLabel(r.doctorSpecialization!),
                  if (r.doctorCode.isNotEmpty) l10n.accessDoctorIdLabel(r.doctorCode),
                ].join(' · '), style: t.bodySmall),
              if (showPatient) ...[
                if (showDoctor) const SizedBox(height: AppSpacing.xs),
                Text(showDoctor ? l10n.accessPatientNameCode(r.patientName, r.patientCode) : l10n.accessPatientNameLabel(r.patientName), style: showDoctor ? t.bodySmall : t.titleSmall),
                if (!showDoctor) Text(l10n.accessPatientIdLabel(r.patientCode), style: t.bodySmall),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.accessRequestedOnLabel(Fmt.dateTime(r.requestedAt)), style: t.bodySmall),
              if (r.respondedAt != null && r.status != AccessStatus.pending) Text('${accessStatusLabel(l10n, r.status)} ${Fmt.dateTime(r.revokedAt ?? r.respondedAt)}', style: t.bodySmall),
            ]),
          ),
          StatusPill(accessStatusLabel(l10n, r.status), tone: r.status.tone),
        ]),
        if (r.message != null && r.message!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: AppRadius.controlBorder),
            child: Text('"${r.message!}"', style: t.bodyMedium),
          ),
        ],
        ..._actions(l10n),
      ]),
    );
  }

  List<Widget> _actions(AppLocalizations l10n) {
    final buttons = <Widget>[
      if (role == UserRole.patient && request.status == AccessStatus.pending) ...[
        FilledButton(onPressed: () => onAction('approve'), child: Text(l10n.accessApproveButton)),
        OutlinedButton(onPressed: () => onAction('reject'), child: Text(l10n.accessRejectButton)),
      ],
      if (request.status == AccessStatus.approved || (role == UserRole.admin && request.status == AccessStatus.pending))
        if (role != UserRole.doctor)
        OutlinedButton(
          onPressed: () => onAction('revoke'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
          child: Text(l10n.accessRevokeAccessButton),
        ),
    ];
    if (buttons.isEmpty) return const [];
    return [const SizedBox(height: AppSpacing.md), Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: buttons)];
  }
}
