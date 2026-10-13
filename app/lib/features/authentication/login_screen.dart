import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import 'auth_controller.dart';
import 'auth_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    try {
      await ref.read(authControllerProvider.notifier).login(_email.text, _password.text);
    } on Failure catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthLayout(
      title: l10n.authWelcomeBack,
      subtitle: l10n.authSignInSubtitle,
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppTextField(label: l10n.authEmailLabel, controller: _email, validator: (v) => Validators.email(l10n, v), keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], textInputAction: TextInputAction.next),
            PasswordField(controller: _password, label: l10n.authPasswordLabel, validator: (v) => Validators.required(l10n, v, l10n.authPasswordLabel), onSubmitted: (_) => _submit()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Semantics(liveRegion: true, child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error))),
              ),
            BusyButton(label: l10n.authSignIn, onPressed: _submit, expand: true),
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.center, child: TextButton(onPressed: () => context.push('/forgot-password'), child: Text(l10n.authForgotPassword))),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.authNewToSusthiti, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: () => context.push('/register'), child: Text(l10n.authCreatePatientAccount)),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.authDoctorAccountsNote, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
