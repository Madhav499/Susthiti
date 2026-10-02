import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
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
    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Sign in to continue to your health overview.',
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppTextField(label: 'Email', controller: _email, validator: Validators.email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], textInputAction: TextInputAction.next),
            PasswordField(controller: _password, validator: (v) => Validators.required(v, 'Password'), onSubmitted: (_) => _submit()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Semantics(liveRegion: true, child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error))),
              ),
            BusyButton(label: 'Sign in', onPressed: _submit, expand: true),
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.center, child: TextButton(onPressed: () => context.push('/forgot-password'), child: const Text('Forgot password?'))),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            Text('New to SUSTHITI?', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: () => context.push('/register'), child: const Text('Create a patient account')),
            const SizedBox(height: AppSpacing.md),
            Text('Doctor accounts are created by your SUSTHITI administrator.', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
