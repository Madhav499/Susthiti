import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../authentication/auth_controller.dart';
import '../notifications/notifications.dart';

/// Account settings for every role. Patient-only sections are shown to patients.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final t = Theme.of(context).textTheme;
    if (user == null) return const SizedBox.shrink();
    final isPatient = user.role == UserRole.patient;
    return AppPage(
      title: 'Settings',
      large: large,
      body: PageBody(maxWidth: 720, children: [
        const SectionHeader('Account'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(user.role == UserRole.doctor ? 'Dr. ${user.fullName}' : user.fullName, style: t.titleMedium)),
              if (user.isDemo) ...[const SizedBox(width: 6), const DemoBadge()],
            ]),
            Text(user.email, style: t.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            StatusPill(user.role.label, tone: StatusTone.info, dot: false),
            if (user.doctorCode != null) ...[const SizedBox(height: AppSpacing.sm), Text('Doctor ID ${user.doctorCode}', style: t.bodySmall)],
          ]),
        ),
        if (isPatient) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(leading: const Icon(Icons.person_outline, color: AppColors.primary), title: const Text('Edit profile'), trailing: const Icon(Icons.chevron_right), onTap: () => context.go('/p/profile')),
          ),
        ],
        if (user.role != UserRole.admin) ...[
          const SizedBox(height: AppSpacing.section),
          const SectionHeader('Notifications'),
          const NotificationPreferencesCard(),
        ],
        if (isPatient) ...[
          const SizedBox(height: AppSpacing.section),
          const SectionHeader('Privacy'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.verified_user_outlined, color: AppColors.primary),
                title: const Text('Doctor access'),
                subtitle: const Text('Approve, reject or revoke doctors who can see your records'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/p/access'),
              ),
              const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
              ListTile(
                leading: const Icon(Icons.watch_outlined, color: AppColors.primary),
                title: const Text('Connected devices'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/p/devices'),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Your records are only visible to you and to doctors you approve. Administrators manage accounts but cannot read your medical records.', style: t.bodySmall),
        ],
        const SizedBox(height: AppSpacing.section),
        const SectionHeader('Security'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.lock_outline, color: AppColors.primary),
              title: const Text('Change password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final changed = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => const _ChangePasswordSheet());
                if (changed == true && context.mounted) showToast(context, 'Password changed');
              },
            ),
            const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Log out'),
              onTap: () async {
                final ok = await confirmAction(context, title: 'Log out?', message: 'You will need to sign in again to see your records.', confirmLabel: 'Log out');
                if (ok) await ref.read(authControllerProvider.notifier).logout();
              },
            ),
          ]),
        ),
        const Disclaimer(),
      ]),
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      await ref.read(authRepositoryProvider).changePassword(_current.text, _next.text);
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetForm(
      title: 'Change password',
      form: _form,
      children: [
        PasswordField(controller: _current, label: 'Current password', validator: (v) => Validators.required(v, 'Current password')),
        PasswordField(controller: _next, label: 'New password', newPassword: true, validator: Validators.password, helper: 'At least 8 characters with a letter and a number.'),
        PasswordField(controller: _confirm, label: 'Confirm new password', newPassword: true, validator: (v) => v != _next.text ? 'Passwords do not match.' : null),
        BusyButton(label: 'Change password', onPressed: _save, expand: true),
      ],
    );
  }
}
