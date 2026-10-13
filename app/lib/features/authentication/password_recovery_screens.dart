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
import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    return AuthLayout(
      title: l10n.authResetPasswordTitle,
      subtitle: l10n.authResetPasswordSubtitle,
      showBack: true,
      child: _sent
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AppCard(
                tinted: true,
                child: Text(l10n.authResetSentMessage, style: t.bodyMedium),
              ),
              if (_devToken != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.authDevModeTitle, style: t.labelSmall?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(l10n.authDevModeBody, style: t.bodySmall),
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
                            tooltip: l10n.authCopyCode,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _devToken!));
                              showToast(context, l10n.authCodeCopied);
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
                child: Text(l10n.authEnterResetCode),
              ),
            ])
          : Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AppTextField(label: l10n.authEmailLabel, controller: _email, validator: (v) => Validators.email(l10n, v), keyboardType: TextInputType.emailAddress),
                BusyButton(label: l10n.authSendResetInstructions, onPressed: _submit, expand: true),
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
    final l10n = AppLocalizations.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      final clean = data.text!.trim().replaceAll(RegExp(r'\D'), '');
      if (clean.length == 8) {
        setState(() {
          _token.text = clean;
        });
        if (mounted) showToast(context, l10n.authPastedCode);
      } else if (clean.isNotEmpty) {
        setState(() {
          _token.text = clean;
        });
        if (mounted) showToast(context, l10n.authPastedCodeGeneric);
      }
    } else {
      if (mounted) showToast(context, l10n.authClipboardEmpty);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    try {
      await ref.read(authRepositoryProvider).resetPassword(_token.text, _password.text);
      if (!mounted) return;
      showToast(context, l10n.authPasswordUpdatedSignIn);
      context.go('/login');
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthLayout(
      title: l10n.authChooseNewPassword,
      subtitle: l10n.authChooseNewPasswordSubtitle,
      showBack: true,
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppTextField(
            label: l10n.auth8DigitCode,
            controller: _token,
            keyboardType: TextInputType.number,
            maxLength: 8,
            suffix: IconButton(
              icon: const Icon(Icons.content_paste_rounded, size: 20),
              tooltip: l10n.authPasteFromClipboard,
              onPressed: _pasteFromClipboard,
            ),
            validator: (v) {
              final req = Validators.required(l10n, v, l10n.auth8DigitCode);
              if (req != null) return req;
              final clean = v!.trim();
              if (clean.length != 8 || int.tryParse(clean) == null) {
                return l10n.authInvalid8DigitCode;
              }
              return null;
            },
          ),
          PasswordField(controller: _password, label: l10n.authNewPassword, validator: (v) => Validators.password(l10n, v), newPassword: true, helper: l10n.authPasswordHelper),
          PasswordField(controller: _confirm, label: l10n.authConfirmNewPassword, validator: (v) => v != _password.text ? l10n.authPasswordsDontMatch : null, newPassword: true),
          BusyButton(label: l10n.authUpdatePassword, onPressed: _submit, expand: true),
        ]),
      ),
    );
  }
}
