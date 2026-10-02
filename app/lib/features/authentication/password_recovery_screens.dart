import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../data/providers.dart';
import 'auth_layout.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;
  String? _devToken;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    try {
      final token = await ref.read(authRepositoryProvider).forgotPassword(_email.text);
      setState(() {
        _sent = true;
        _devToken = token;
      });
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AuthLayout(
      title: 'Reset your password',
      subtitle: 'Enter the email you use for SUSTHITI and we will send reset instructions.',
      showBack: true,
      child: _sent
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AppCard(
                tinted: true,
                child: Text('If an account exists for this email, password reset instructions have been sent.', style: t.bodyMedium),
              ),
              if (_devToken != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('DEVELOPMENT MODE', style: t.labelSmall?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('No email provider is configured on this server, so the reset code is shown here. This never happens in production.', style: t.bodySmall),
                  ]),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => context.push('/reset-password', extra: _devToken),
                child: const Text('Enter reset code'),
              ),
            ])
          : Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AppTextField(label: 'Email', controller: _email, validator: Validators.email, keyboardType: TextInputType.emailAddress),
                BusyButton(label: 'Send reset instructions', onPressed: _submit, expand: true),
              ]),
            ),
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.prefilledToken});
  final String? prefilledToken;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _token = TextEditingController(text: widget.prefilledToken ?? '');
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    try {
      await ref.read(authRepositoryProvider).resetPassword(_token.text, _password.text);
      if (!mounted) return;
      showToast(context, 'Your password has been updated. Please sign in.');
      context.go('/login');
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Choose a new password',
      subtitle: 'Enter the reset code you received and a new password.',
      showBack: true,
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppTextField(label: 'Reset code', controller: _token, validator: (v) => Validators.required(v, 'Reset code')),
          PasswordField(controller: _password, label: 'New password', validator: Validators.password, newPassword: true, helper: 'At least 8 characters with a letter and a number.'),
          PasswordField(controller: _confirm, label: 'Confirm new password', validator: (v) => v != _password.text ? 'Passwords do not match.' : null, newPassword: true),
          BusyButton(label: 'Update password', onPressed: _submit, expand: true),
        ]),
      ),
    );
  }
}
