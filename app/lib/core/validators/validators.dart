/// Form validators. They mirror the backend rules; the backend re-validates everything.
abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phone = RegExp(r'^\+?[0-9 ()-]{7,20}$');
  static final _patientId = RegExp(r'^SUS-P-[0-9A-F]{6}$');

  static String? required(String? v, [String label = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$label is required.' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required.';
    return _email.hasMatch(v.trim()) ? null : 'Enter a valid email address.';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    if (v.length < 8) return 'Use at least 8 characters.';
    if (!v.contains(RegExp(r'[A-Za-z]')) || !v.contains(RegExp(r'[0-9]'))) return 'Include at least one letter and one number.';
    return null;
  }

  static String? optionalPhone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return _phone.hasMatch(v.trim()) ? null : 'Enter a valid phone number.';
  }

  static String? patientId(String? v) {
    if (v == null || v.trim().isEmpty) return 'Patient ID is required.';
    return _patientId.hasMatch(v.trim().toUpperCase()) ? null : 'Patient ID should look like SUS-P-8A42F1.';
  }

  static String? age(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null) return 'Enter your age in whole years.';
    if (n < 1 || n > 120) return 'Age must be between 1 and 120.';
    return null;
  }

  static String? glucose(String? v, String unit) {
    final n = double.tryParse(v?.trim() ?? '');
    if (n == null) return 'Enter a number.';
    final (low, high) = unit == 'mg/dL' ? (20.0, 600.0) : (1.1, 33.3);
    if (n < low || n > high) return 'Enter a value between $low and $high $unit.';
    return null;
  }

  static String? numberInRange(String? v, num low, num high, {String label = 'Value'}) {
    final n = num.tryParse(v?.trim() ?? '');
    if (n == null) return 'Enter a number.';
    if (n < low || n > high) return '$label must be between $low and $high.';
    return null;
  }

  static String? notFuture(DateTime? d, [String label = 'Date']) {
    if (d == null) return '$label is required.';
    if (d.isAfter(DateTime.now().add(const Duration(minutes: 5)))) return "$label can't be in the future.";
    return null;
  }
}
