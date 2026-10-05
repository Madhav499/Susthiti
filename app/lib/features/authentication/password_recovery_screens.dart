import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                    Text('No email provider is configured on this server, so the 8-digit reset code is shown below. This never happens in production.', style: t.bodySmall),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SelectableText(
                            _devToken!,
                            style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 4, color: AppColors.primary),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            tooltip: 'Copy code',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _devToken!));
                              showToast(context, 'Reset code copied to clipboard');
                            },
                          ),
                        ],
                      ),
                    ),
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

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      final clean = data.text!.trim().replaceAll(RegExp(r'\D'), '');
      if (clean.length == 8) {
        setState(() {
          _token.text = clean;
        });
        if (mounted) showToast(context, 'Pasted 8-digit code from clipboard');
      } else if (clean.isNotEmpty) {
        setState(() {
          _token.text = clean;
        });
        if (mounted) showToast(context, 'Pasted code from clipboard');
      }
    } else {
      if (mounted) showToast(context, 'Clipboard is empty');
    }
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
      subtitle: 'Enter the 8-digit reset code you received and a new password.',
      showBack: true,
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppTextField(
            label: '8-digit reset code',
            controller: _token,
            keyboardType: TextInputType.number,
            maxLength: 8,
            suffix: IconButton(
              icon: const Icon(Icons.content_paste_rounded, size: 20),
              tooltip: 'Paste from clipboard',
              onPressed: _pasteFromClipboard,
            ),
            validator: (v) {
              final req = Validators.required(v, 'Reset code');
              if (req != null) return req;
              final clean = v!.trim();
              if (clean.length != 8 || int.tryParse(clean) == null) {
                return 'Enter the 8-digit code from your email.';
              }
              return null;
            },
          ),
          PasswordField(controller: _password, label: 'New password', validator: Validators.password, newPassword: true, helper: 'At least 8 characters with a letter and a number.'),
          PasswordField(controller: _confirm, label: 'Confirm new password', validator: (v) => v != _password.text ? 'Passwords do not match.' : null, newPassword: true),
          BusyButton(label: 'Update password', onPressed: _submit, expand: true),
        ]),
      ),
    );
  }
}
