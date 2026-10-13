import 'package:flutter/material.dart';

import '../../data/models/user.dart';
import '../../l10n/app_localizations.dart';
import 'form_fields.dart';

/// Shown on registration and in account settings alike, so both pickers stay in sync.
String languageLabel(AppLocalizations l10n, String code) => switch (code) {
      'hi' => l10n.languageHindi,
      'gu' => l10n.languageGujarati,
      _ => l10n.languageEnglish,
    };

/// The three-way language choice ([kSupportedLocales]): English, हिन्दी, ગુજરાતી.
class LanguageField extends StatelessWidget {
  const LanguageField({super.key, required this.value, required this.onChanged, this.helper});

  final String value;
  final ValueChanged<String> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LabeledField(
      label: l10n.authLanguageLabel,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ChoiceChips<String>(
          options: kSupportedLocales,
          selected: value,
          labelOf: (code) => languageLabel(l10n, code),
          onSelected: onChanged,
        ),
        if (helper != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(helper!, style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }
}
