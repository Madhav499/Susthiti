import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/language_field.dart';
import '../../l10n/app_localizations.dart';
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
  // Defaults to English; the user picks explicitly before the account (and this
  // preference) is created. Changeable any time afterwards from Settings.
  String _locale = 'en';
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
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    if (!_accepted) {
      setState(() => _error = l10n.authConsentError);
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).register(
            fullName: _name.text, email: _email.text, password: _password.text, dateOfBirth: _dob!, gender: _gender!, phone: _phone.text,
            preferredLocale: _locale,
          );
    } on Failure catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force the selected locale even before authentication: the user's choice on this screen
    // determines their account preference, so the form should reflect it immediately.
    return Localizations.override(
      context: context,
      locale: Locale(_locale),
      child: Builder(builder: (context) {
        final t = Theme.of(context).textTheme;
        final l10n = AppLocalizations.of(context);
        return AuthLayout(
          title: l10n.authCreateAccountTitle,
          subtitle: l10n.authCreateAccountSubtitle,
          showBack: true,
          child: AutofillGroup(
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AppTextField(label: l10n.authFullName, controller: _name, validator: (v) => Validators.required(l10n, v, l10n.authFullName), autofillHints: const [AutofillHints.name], textCapitalization: TextCapitalization.words),
                AppTextField(label: l10n.authEmailLabel, controller: _email, validator: (v) => Validators.email(l10n, v), keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email]),
                DateTimeField(
                  label: l10n.authDateOfBirth,
                  value: _dob,
                  onChanged: (d) => setState(() => _dob = d),
                  lastDate: DateTime.now(),
                  validator: (d) => Validators.notFuture(l10n, d, l10n.authDateOfBirth),
                ),
                ChoiceField<String>(
                  label: l10n.authGender,
                  options: const ['Male', 'Female'],
                  value: _gender,
                  labelOf: (g) => g == 'Male' ? l10n.genderMale : l10n.genderFemale,
                  onChanged: (g) => setState(() => _gender = g),
                  requiredMessage: l10n.authGenderRequired,
                ),
                AppTextField(label: l10n.authPhone, controller: _phone, optional: true, validator: (v) => Validators.optionalPhone(l10n, v), keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber]),
                PasswordField(controller: _password, label: l10n.authPasswordLabel, validator: (v) => Validators.password(l10n, v), newPassword: true, helper: l10n.authPasswordHelper),
                LanguageField(value: _locale, onChanged: (v) => setState(() => _locale = v), helper: l10n.authLanguageHelper),
                CheckboxListTile(
                  value: _accepted,
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(l10n.authConsentText, style: t.bodySmall),
                ),
                if (_error != null)
                  Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Text(_error!, style: t.bodyMedium?.copyWith(color: AppColors.error))),
                const SizedBox(height: AppSpacing.sm),
                BusyButton(label: l10n.authCreateAccountButton, onPressed: _submit, expand: true),
              ]),
            ),
          ),
        );
      }),
    );
  }
}
