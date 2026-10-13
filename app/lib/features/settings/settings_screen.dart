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
import '../../core/widgets/language_field.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../authentication/auth_controller.dart';
import '../notifications/notifications.dart';

/// Account settings for every role. Patient-only sections are shown to patients.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.large = false});
  final bool large;

  Future<void> _changeLanguage(BuildContext context, WidgetRef ref, String locale) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(authControllerProvider.notifier).updateLanguage(locale);
      if (context.mounted) showToast(context, l10n.settingsLanguageUpdated);
    } on Failure catch (_) {
      if (context.mounted) showToast(context, l10n.settingsLanguageUpdateFailed, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    if (user == null) return const SizedBox.shrink();
    final isPatient = user.role == UserRole.patient;
    return AppPage(
      title: l10n.settingsTitle,
      large: large,
      body: PageBody(maxWidth: 720, children: [
        SectionHeader(l10n.settingsAccount),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(user.role == UserRole.doctor ? 'Dr. ${user.fullName}' : user.fullName, style: t.titleMedium)),
              if (user.isDemo) ...[const SizedBox(width: 6), const DemoBadge()],
            ]),
            Text(user.email, style: t.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            StatusPill(user.role.label, tone: StatusTone.info, dot: false),
            if (user.doctorCode != null) ...[const SizedBox(height: AppSpacing.sm), Text(l10n.settingsDoctorIdLabel(user.doctorCode!), style: t.bodySmall)],
          ]),
        ),
        if (isPatient) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(leading: const Icon(Icons.person_outline, color: AppColors.primary), title: Text(l10n.settingsEditProfile), trailing: const Icon(Icons.chevron_right), onTap: () => context.go('/p/profile')),
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        SectionHeader(l10n.settingsLanguageTitle),
        AppCard(
          child: LanguageField(value: user.preferredLocale, onChanged: (v) => _changeLanguage(context, ref, v), helper: l10n.settingsLanguageSubtitle),
        ),
        if (user.role != UserRole.admin) ...[
          const SizedBox(height: AppSpacing.section),
          SectionHeader(l10n.settingsNotifications),
          const NotificationPreferencesCard(),
        ],
        if (isPatient) ...[
          const SizedBox(height: AppSpacing.section),
          SectionHeader(l10n.settingsPrivacy),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.verified_user_outlined, color: AppColors.primary),
                title: Text(l10n.settingsDoctorAccess),
                subtitle: Text(l10n.settingsDoctorAccessSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/p/access'),
              ),
              const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
              ListTile(
                leading: const Icon(Icons.watch_outlined, color: AppColors.primary),
                title: Text(l10n.settingsConnectedDevices),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/p/devices'),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.settingsPrivacyNote, style: t.bodySmall),
        ],
        const SizedBox(height: AppSpacing.section),
        SectionHeader(l10n.settingsSecurity),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.lock_outline, color: AppColors.primary),
              title: Text(l10n.settingsChangePassword),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final changed = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => const _ChangePasswordSheet());
                if (changed == true && context.mounted) showToast(context, l10n.settingsPasswordChanged);
              },
            ),
            const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: Text(l10n.settingsLogOut),
              onTap: () async {
                final ok = await confirmAction(context, title: l10n.settingsLogOutConfirmTitle, message: l10n.settingsLogOutConfirmMessage, confirmLabel: l10n.settingsLogOut);
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
    final l10n = AppLocalizations.of(context);
    return SheetForm(
      title: l10n.settingsChangePassword,
      form: _form,
      children: [
        PasswordField(controller: _current, label: l10n.settingsCurrentPassword, validator: (v) => Validators.required(l10n, v, l10n.settingsCurrentPassword)),
        PasswordField(controller: _next, label: l10n.settingsNewPassword, newPassword: true, validator: (v) => Validators.password(l10n, v), helper: l10n.authPasswordHelper),
        PasswordField(controller: _confirm, label: l10n.settingsConfirmNewPassword, newPassword: true, validator: (v) => v != _next.text ? l10n.authPasswordsDontMatch : null),
        BusyButton(label: l10n.settingsChangePassword, onPressed: _save, expand: true),
      ],
    );
  }
}
