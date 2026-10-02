import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';

/// Label above the input, then supporting text / validation below (no placeholder-only fields).
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child, this.optional = false});

  final String label;
  final Widget child;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: t.labelLarge?.copyWith(fontWeight: FontWeight.w500)),
          if (optional) Text('  Optional', style: t.labelMedium),
        ]),
        const SizedBox(height: 6),
        child,
      ]),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.helper,
    this.hint,
    this.validator,
    this.keyboardType,
    this.obscure = false,
    this.maxLines = 1,
    this.optional = false,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
    this.suffix,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLength,
  });

  final String label;
  final TextEditingController? controller;
  final String? helper;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscure;
  final int maxLines;
  final bool optional;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffix;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: label,
      optional: optional,
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscure,
        maxLines: obscure ? 1 : maxLines,
        enabled: enabled,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onFieldSubmitted: onFieldSubmitted,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        decoration: InputDecoration(helperText: helper, hintText: hint, suffixIcon: suffix, counterText: ''),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, this.label = 'Password', this.helper, this.validator, this.newPassword = false, this.onSubmitted});

  final TextEditingController controller;
  final String label;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final bool newPassword;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      helper: widget.helper,
      validator: widget.validator,
      obscure: _hidden,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
      suffix: IconButton(
        tooltip: _hidden ? 'Show password' : 'Hide password',
        icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        onPressed: () => setState(() => _hidden = !_hidden),
      ),
    );
  }
}

/// Tap-to-pick date (and optional time) field with validation.
class DateTimeField extends FormField<DateTime> {
  DateTimeField({
    super.key,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onChanged,
    bool includeTime = false,
    DateTime? firstDate,
    DateTime? lastDate,
    String? helper,
    bool optional = false,
    super.validator,
  }) : super(
          initialValue: value,
          builder: (state) {
            final context = state.context;
            final current = state.value;
            Future<void> pick() async {
              final now = DateTime.now();
              final date = await showDatePicker(
                context: context,
                initialDate: current ?? (lastDate != null && lastDate.isBefore(now) ? lastDate : now),
                firstDate: firstDate ?? DateTime(1900),
                lastDate: lastDate ?? now,
              );
              if (date == null || !context.mounted) return;
              var result = date;
              if (includeTime) {
                final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current ?? now));
                if (time == null) return;
                result = DateTime(date.year, date.month, date.day, time.hour, time.minute);
              }
              state.didChange(result);
              onChanged(result);
            }

            final text = current == null ? 'Select' : (includeTime ? Fmt.dateTime(current) : Fmt.date(current));
            return LabeledField(
              label: label,
              optional: optional,
              child: InkWell(
                onTap: pick,
                borderRadius: AppRadius.controlBorder,
                child: InputDecorator(
                  decoration: InputDecoration(
                    helperText: helper,
                    errorText: state.errorText,
                    suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                  ),
                  child: Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: current == null ? AppColors.inactive : null)),
                ),
              ),
            );
          },
        );
}

/// Compact single-choice chips (reading type, meal type, severity...).
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({super.key, required this.options, required this.selected, required this.onSelected, required this.labelOf});

  final List<T> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
      for (final o in options)
        ChoiceChip(
          label: Text(labelOf(o)),
          selected: o == selected,
          onSelected: (_) => onSelected(o),
          labelStyle: TextStyle(color: o == selected ? AppColors.primary : AppColors.textPrimary, fontWeight: o == selected ? FontWeight.w600 : FontWeight.w400),
          side: BorderSide(color: o == selected ? AppColors.primary : AppColors.border),
        ),
    ]);
  }
}

/// Form-field wrapper so chip groups participate in validation.
class ChoiceField<T> extends FormField<T> {
  ChoiceField({
    super.key,
    required String label,
    required List<T> options,
    required T? value,
    required ValueChanged<T> onChanged,
    required String Function(T) labelOf,
    String? helper,
    String requiredMessage = 'Please choose one option.',
  }) : super(
          initialValue: value,
          validator: (v) => v == null ? requiredMessage : null,
          builder: (state) {
            final t = Theme.of(state.context).textTheme;
            return LabeledField(
              label: label,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ChoiceChips<T>(
                  options: options,
                  selected: state.value,
                  labelOf: labelOf,
                  onSelected: (v) {
                    state.didChange(v);
                    onChanged(v);
                  },
                ),
                if (state.hasError)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(state.errorText!, style: t.bodySmall?.copyWith(color: AppColors.error)))
                else if (helper != null)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(helper, style: t.bodySmall)),
              ]),
            );
          },
        );
}

/// Consistent bottom-sheet form container.
class SheetForm extends StatelessWidget {
  const SheetForm({super.key, required this.title, required this.form, required this.children});
  final String title;
  final GlobalKey<FormState> form;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
          child: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              ...children,
            ]),
          ),
        ),
      ),
    );
  }
}
