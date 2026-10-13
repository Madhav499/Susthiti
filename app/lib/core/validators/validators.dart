import '../../l10n/app_localizations.dart';

/// Form validators. They mirror the backend rules; the backend re-validates everything.
/// Every method takes the current [AppLocalizations] so messages render in the active
/// locale -- callers already have it in scope wherever a form is built.
abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phone = RegExp(r'^\+?[0-9 ()-]{7,20}$');
  static final _patientId = RegExp(r'^SUS-P-[0-9A-F]{6}$');

  static String? required(AppLocalizations l10n, String? v, [String? label]) =>
      (v == null || v.trim().isEmpty) ? l10n.validatorRequiredField(label ?? l10n.validatorThisField) : null;

  static String? email(AppLocalizations l10n, String? v) {
    if (v == null || v.trim().isEmpty) return l10n.validatorEmailRequired;
    return _email.hasMatch(v.trim()) ? null : l10n.validatorEmailInvalid;
  }

  static String? password(AppLocalizations l10n, String? v) {
    if (v == null || v.isEmpty) return l10n.validatorPasswordRequired;
    if (v.length < 8) return l10n.validatorPasswordTooShort;
    if (!v.contains(RegExp(r'[A-Za-z]')) || !v.contains(RegExp(r'[0-9]'))) return l10n.validatorPasswordNeedsLetterNumber;
    return null;
  }

  static String? optionalPhone(AppLocalizations l10n, String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return _phone.hasMatch(v.trim()) ? null : l10n.validatorPhoneInvalid;
  }

  static String? patientId(AppLocalizations l10n, String? v) {
    if (v == null || v.trim().isEmpty) return l10n.validatorPatientIdRequired;
    return _patientId.hasMatch(v.trim().toUpperCase()) ? null : l10n.validatorPatientIdInvalid;
  }

  static String? age(AppLocalizations l10n, String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null) return l10n.validatorAgeInvalid;
    if (n < 1 || n > 120) return l10n.validatorAgeRange;
    return null;
  }

  static String? glucose(AppLocalizations l10n, String? v, String unit) {
    final n = double.tryParse(v?.trim() ?? '');
    if (n == null) return l10n.validatorNumberRequired;
    final (low, high) = unit == 'mg/dL' ? (20.0, 600.0) : (1.1, 33.3);
    if (n < low || n > high) return l10n.validatorGlucoseRange('$low', '$high', unit);
    return null;
  }

  static String? numberInRange(AppLocalizations l10n, String? v, num low, num high, {String? label}) {
    final n = num.tryParse(v?.trim() ?? '');
    if (n == null) return l10n.validatorNumberRequired;
    if (n < low || n > high) return l10n.validatorNumberRange(label ?? l10n.validatorValueLabel, '$low', '$high');
    return null;
  }

  static String? notFuture(AppLocalizations l10n, DateTime? d, [String? label]) {
    if (d == null) return l10n.validatorRequiredField(label ?? l10n.validatorDateLabel);
    if (d.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return l10n.validatorDateNotFuture(label ?? l10n.validatorDateLabel);
    }
    return null;
  }
}
