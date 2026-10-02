import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import 'auth_controller.dart';
import 'auth_layout.dart';

/// Public registration creates PATIENT accounts only.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  DateTime? _dob;
  String? _gender;
  bool _accepted = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    if (!_accepted) {
      setState(() => _error = 'Please confirm you understand SUSTHITI does not replace medical care.');
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).register(
            fullName: _name.text, email: _email.text, password: _password.text, dateOfBirth: _dob!, gender: _gender!, phone: _phone.text,
          );
    } on Failure catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AuthLayout(
      title: 'Create your account',
      subtitle: 'Start building your health history. You can add more details later.',
      showBack: true,
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppTextField(label: 'Full name', controller: _name, validator: (v) => Validators.required(v, 'Full name'), autofillHints: const [AutofillHints.name], textCapitalization: TextCapitalization.words),
            AppTextField(label: 'Email', controller: _email, validator: Validators.email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email]),
            DateTimeField(
              label: 'Date of birth',
              value: _dob,
              onChanged: (d) => setState(() => _dob = d),
              lastDate: DateTime.now(),
              validator: (d) => Validators.notFuture(d, 'Date of birth'),
            ),
            ChoiceField<String>(label: 'Gender', options: const ['Male', 'Female'], value: _gender, labelOf: (g) => g, onChanged: (g) => setState(() => _gender = g), requiredMessage: 'Please choose a gender.'),
            AppTextField(label: 'Phone', controller: _phone, optional: true, validator: Validators.optionalPhone, keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber]),
            PasswordField(controller: _password, validator: Validators.password, newPassword: true, helper: 'At least 8 characters with a letter and a number.'),
            CheckboxListTile(
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('I understand SUSTHITI provides informational insights and does not replace professional medical diagnosis, treatment, or emergency care.', style: t.bodySmall),
            ),
            if (_error != null)
              Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Text(_error!, style: t.bodyMedium?.copyWith(color: AppColors.error))),
            const SizedBox(height: AppSpacing.sm),
            BusyButton(label: 'Create account', onPressed: _submit, expand: true),
          ]),
        ),
      ),
    );
  }
}
