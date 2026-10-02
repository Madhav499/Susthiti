import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    if (action != 'approve') {
      final ok = await confirmAction(
        context,
        title: switch (action) { 'reject' => 'Reject request?', _ => 'Revoke access?' },
        message: switch (action) {
          'reject' => 'Dr. ${r.doctorName} will not be able to see your records.',
          _ => role == UserRole.admin
              ? 'Dr. ${r.doctorName} will immediately lose access to ${r.patientName}\'s records. The patient and doctor are notified.'
              : 'Dr. ${r.doctorName} will immediately lose access to your records. Records they created stay in your history.',
        },
        confirmLabel: action == 'reject' ? 'Reject' : 'Revoke',
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
      if (mounted) showToast(context, switch (action) { 'approve' => 'Access approved', 'reject' => 'Request rejected', _ => 'Access revoked' });
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserProvider)?.role ?? UserRole.patient;
    final value = ref.watch(accessRequestsProvider(role));
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: switch (role) { UserRole.patient => 'Doctor Access', UserRole.doctor => 'Access Requests', UserRole.admin => 'Access Review' },
      large: widget.large,
      body: PageBody(
        maxWidth: 820,
        onRefresh: () async => ref.invalidate(accessRequestsProvider(role)),
        children: [
          if (role == UserRole.patient) ...[
            Text('Doctors can only see your records after you approve them. You can revoke access at any time.', style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final s in <AccessStatus?>[null, ...AccessStatus.values])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(label: Text(s?.label ?? 'All'), selected: _filter == s, onSelected: (_) => setState(() => _filter = s)),
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
                  title: _filter == null ? 'No access requests.' : 'No ${_filter!.label.toLowerCase()} requests.',
                  message: role == UserRole.patient && _filter == null ? 'When a doctor requests access using your name and Patient ID, it will appear here.' : null,
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
              if (showDoctor) Text('Dr. ${r.doctorName}', style: t.titleSmall),
              if (showDoctor) Text([r.doctorSpecialization, r.doctorCode].whereType<String>().join(' · '), style: t.bodySmall),
              if (showPatient) ...[
                if (showDoctor) const SizedBox(height: AppSpacing.xs),
                Text(showDoctor ? 'Patient: ${r.patientName} · ${r.patientCode}' : r.patientName, style: showDoctor ? t.bodySmall : t.titleSmall),
                if (!showDoctor) Text(r.patientCode, style: t.bodySmall),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text('Requested ${Fmt.dateTime(r.requestedAt)}', style: t.bodySmall),
              if (r.respondedAt != null && r.status != AccessStatus.pending) Text('${r.status.label} ${Fmt.dateTime(r.revokedAt ?? r.respondedAt)}', style: t.bodySmall),
            ]),
          ),
          StatusPill(r.status.label, tone: r.status.tone),
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
        ..._actions(),
      ]),
    );
  }

  List<Widget> _actions() {
    final buttons = <Widget>[
      if (role == UserRole.patient && request.status == AccessStatus.pending) ...[
        FilledButton(onPressed: () => onAction('approve'), child: const Text('Approve')),
        OutlinedButton(onPressed: () => onAction('reject'), child: const Text('Reject')),
      ],
      if (request.status == AccessStatus.approved || (role == UserRole.admin && request.status == AccessStatus.pending))
        if (role != UserRole.doctor)
        OutlinedButton(
          onPressed: () => onAction('revoke'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
          child: const Text('Revoke access'),
        ),
    ];
    if (buttons.isEmpty) return const [];
    return [const SizedBox(height: AppSpacing.md), Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: buttons)];
  }
}
