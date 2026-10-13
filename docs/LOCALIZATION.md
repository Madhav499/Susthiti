# SUSTHITI Multilingual Localization

**Last Updated:** 2026-10-13
**Status:** Core implementation complete, clinical validation required

## Supported Languages

SUSTHITI is available in three languages:

- **English (en)** - Default, fully supported
- **à¤¹à¤¿à¤¨à¥à¤¦à¥€ / Hindi (hi)** - Fully supported in UI, PDF English-only
- **àª—à«àªœàª°àª¾àª¤à«€ / Gujarati (gu)** - Fully supported in UI, PDF English-only

## Locale Selection and Persistence

### User Experience Flow

1. **Sign-Up (Unauthenticated):**
   - User selects language on registration screen
   - Form updates immediately with selected language
   - Selection becomes user's account preference

2. **Account Preference:**
   - Stored in database as `User.preferred_locale`
   - Persists across logout/login cycles
   - Independent per account (multi-user device safe)

3. **Language Switching:**
   - Can be changed anytime in Settings
   - Updates immediately across entire app
   - Does not affect other accounts on same device

### Technical Implementation

**Frontend (`app/`):**
- `lib/core/services/app_locale.dart` - Provides `appLocaleProvider` tied to authenticated user
- `lib/features/authentication/register_screen.dart` - Uses `Localizations.override` for pre-login locale
- `lib/l10n/` - Generated localization classes from ARB files

**Backend (`backend/`):**
- `app/models.py` - `User.preferred_locale` field
- `app/services/i18n.py` - `normalize_locale()` and fallback handling
- Default: English for null/invalid/unsupported locales

## Adding New Translation Keys

### 1. Add to English ARB Template

Edit `app/lib/l10n/app_en.arb`:

```json
{
  "myNewKey": "English text",
  "@myNewKey": {
    "description": "Brief context for translators"
  }
}
```

### 2. Add Translations

Add equivalent keys to `app_hi.arb` and `app_gu.arb`:

```json
{
  "myNewKey": "à¤¹à¤¿à¤¨à¥à¤¦à¥€ à¤ªà¤¾à¤ "
}
```

### 3. Regenerate Localization Code

```bash
cd app
flutter gen-l10n
```

### 4. Use in Code

```dart
import '../../l10n/app_localizations.dart';

Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return Text(l10n.myNewKey);
}
```

## Localizing Status and Role Labels

**DO NOT** use enum `.label` getters or `.name` directly. Use localization helper functions:

```dart
import '../../core/l10n/enum_labels.dart';

// âœ… CORRECT - Localized
Text(accessStatusLabel(l10n, status))
Text(userRoleLabel(l10n, role))
Text(severityLabel(l10n, severity))
Text(genderLabel(l10n, gender))

// âŒ WRONG - Hardcoded English
Text(status.label)
Text(role.label)
Text(gender)
```

**Available Helper Functions:**
- `accessStatusLabel()` - Pending, Approved, Rejected, Revoked
- `userRoleLabel()` - Patient, Doctor, Admin
- `severityLabel()` - Mild, Moderate, Severe, Emergency
- `sideEffectStatusLabel()` - New, Under Review, Responded, etc.
- `followUpStatusLabel()` - Upcoming, Completed, Cancelled
- `genderLabel()` - Male, Female

## AI Translation and Fallbacks

### How It Works

1. **Canonical Summary (English):**
   - AI generates English summary from patient data
   - Stored as `content` in database

2. **Translation on Demand:**
   - When Hindi/Gujarati user requests summary, backend translates
   - Translation cached for future requests
   - Numeric values preserved exactly (no rounding/reformatting)

3. **Fallback Behavior:**
   - If translation unavailable or fails, shows English version
   - Backend sets `used_fallback: true` in API response
   - UI should display clear notice (implementation in progress)

### Translation Quality Validation

**Numeric Integrity Check:**
- Automatic: Extracts numbers from original and translation
- Rejects translation if numbers don't match
- Falls back to English to prevent data corruption

**Safety Validation:**
- Checks for medication dosage instructions
- Checks for emergency declarations
- Checks for diagnosis certainty claims
- Rejects unsafe content, regenerates or falls back

## PDF Language Support

### Current Limitation âš ï¸

**PDFs are currently generated in English only**, regardless of user locale.

**Reason:** ReportLab uses Helvetica font which has no support for Devanagari (Hindi) or Gujarati scripts. Generating Hindi/Gujarati PDFs with current implementation would result in unreadable output with missing glyphs (â–¡â–¡â–¡).

**User Experience:**
- UI displays notice: "PDF exports are currently available in English only"
- Hindi/Gujarati users see localized UI but download English PDFs
- PDF content is accurate, just not translated

### Implementing Full PDF Support

**Requirements to enable Hindi/Gujarati PDFs:**

1. **Bundle Unicode Fonts:**
   ```
   backend/fonts/
   â”œâ”€â”€ NotoSansDevanagari-Regular.ttf
   â””â”€â”€ NotoSansGujarati-Regular.ttf
   ```
   (Open source, Apache 2.0 license - verify before bundling)

2. **Register Fonts with ReportLab:**
   ```python
   from reportlab.pdfbase import pdfmetrics
   from reportlab.pdfbase.ttfonts import TTFont

   pdfmetrics.registerFont(TTFont('NotoSansDevanagari', 'fonts/NotoSansDevanagari-Regular.ttf'))
   pdfmetrics.registerFont(TTFont('NotoSansGujarati', 'fonts/NotoSansGujarati-Regular.ttf'))
   ```

3. **Update Style Definitions (`backend/app/services/pdf.py`):**
   ```python
   def _styles(locale: str):
       font = {
           'hi': 'NotoSansDevanagari',
           'gu': 'NotoSansGujarati',
       }.get(locale, 'Helvetica')

       base = dict(fontName=font, ...)
   ```

4. **Verify Indic Script Rendering:**
   - Generate test PDFs with actual Hindi/Gujarati content
   - Visual inspection required - automated checks insufficient
   - Verify conjuncts (e.g., à¤• + à¥ + à¤· = à¤•à¥à¤·) render correctly
   - Verify vowel marks (matra) position correctly
   - Test with medical terminology and full paragraphs

5. **Remove English-Only Override:**
   Delete forced locale override in `render_summary_pdf()` (currently at line ~418)

**Estimated Implementation:** 4-6 hours including testing

## Medical Translation Review

### âš ï¸ CRITICAL: Clinical Validation Required

**Current Status:** All 1,389 Hindi and Gujarati translations are **programmatically validated but NOT clinically reviewed**.

**Automated Validation (Complete):**
- âœ… Unicode integrity (no mojibake or corruption)
- âœ… Script correctness (proper Devanagari/Gujarati)
- âœ… Placeholder consistency
- âœ… JSON structure validity
- âœ… Character set verification

**Required Before Production:**

Medical translations MUST be reviewed by:
- Native Hindi/Gujarati speaker
- Healthcare background (doctor, nurse, medical translator)
- Familiar with medical terminology in target language
- Understanding of formal medical communication standards

**Focus Areas for Review:**
1. Medical terminology accuracy (diabetes, heart disease, risk levels)
2. Safety disclaimers legal/medical appropriateness
3. Medication and treatment guidance clarity
4. Assessment interpretation phrasing
5. Cultural appropriateness for healthcare context
6. Formality level suitable for doctor-patient communication

**Specific Concerns to Verify:**
- Is "AI" spelled out or abbreviation used?
- Are diabetes/heart condition terms clinically standard?
- Do patients understand technical medical terms?
- Are risk level descriptions (Mild, Moderate, Severe) appropriate?
- Is disclaimer language legally sufficient?

**Risk:** Incorrect medical translations could lead to patient harm through misunderstanding of health guidance.

## Adding a New Language

1. **Update Backend Constants:**
   ```python
   # backend/app/models.py
   SUPPORTED_LOCALES = ['en', 'hi', 'gu', 'ta']  # Add Tamil
   ```

2. **Create ARB File:**
   ```bash
   cp app/lib/l10n/app_en.arb app/lib/l10n/app_ta.arb
   # Translate all 1,389 keys
   ```

3. **Update Flutter Configuration:**
   ```yaml
   # app/l10n.yaml
   arb-dir: lib/l10n
   template-arb-file: app_en.arb
   output-localization-file: app_localizations.dart
   ```

4. **Add Backend Translations:**
   ```python
   # backend/app/services/i18n.py
   DISCLAIMER_BY_LOCALE = {
       'en': '...',
       'hi': '...',
       'gu': '...',
       'ta': '...',  # Add Tamil
   }
   ```

5. **Update Language Selector:**
   ```dart
   // app/lib/data/models/user.dart
   const List<String> kSupportedLocales = ['en', 'hi', 'gu', 'ta'];

   // app/lib/core/widgets/language_field.dart
   String languageLabel(AppLocalizations l10n, String code) => switch (code) {
     'hi' => l10n.languageHindi,
     'gu' => l10n.languageGujarati,
     'ta' => l10n.languageTamil,  // Add
     _ => l10n.languageEnglish,
   };
   ```

6. **Regenerate and Test:**
   ```bash
   cd app && flutter gen-l10n
   flutter test
   cd ../backend && python -m pytest tests/test_locale_preference.py
   ```

## Known Issues and Limitations

### Current Limitations

1. **PDF Export (High Priority):**
   - âš ï¸ Hindi and Gujarati PDFs not supported (English-only fallback active)
   - Requires font bundling and extensive testing
   - See "Implementing Full PDF Support" section above

2. **Medical Translation Validation (Critical Priority):**
   - âš ï¸ All Hindi/Gujarati translations require clinical review
   - Technical validation complete, medical accuracy unverified
   - See "Medical Translation Review" section above

3. **AI Summary Fallback Indicator (Medium Priority):**
   - UI does not clearly show when English fallback is used
   - Keys added: `aiSummaryFallbackNotice`, `aiSummaryRequestTranslation`
   - Integration incomplete in `lib/features/ai/ai_summary_section.dart`

### Language-Specific Behaviors

**Date/Time Formatting:**
- Currently formatted in English regardless of locale
- Future enhancement: Locale-aware date formatting

**Number Formatting:**
- Medical values (glucose, HbA1c) use standard international format
- Intentionally not localized to prevent clinical confusion
- Units remain in standard medical notation (mg/dL, mmol/L)

**Personal Data:**
- Names, email addresses, phone numbers never translated
- Patient-entered text displayed as-is
- Medical IDs and codes remain unchanged
- Transliteration of names into Hindi or Gujarati script is a separate optional feature and requires explicit product rules and user confirmation

## Testing Localization

### Backend Tests

```bash
cd backend
python -m pytest tests/test_locale_preference.py -v  # 8 tests
python -m pytest tests/test_disclaimer_localization.py -v  # 8 tests
python -m pytest tests/test_ai_localization.py -v  # 4 tests
```

### Flutter Widget Tests

```bash
cd app
flutter test test/widget/register_screen_test.dart
flutter test test/widget/access_requests_test.dart
flutter test test/widget/login_screen_test.dart
```

### Manual Testing Checklist

- [ ] Select Hindi on registration, verify form updates immediately
- [ ] Create account in Gujarati, verify locale persists after login
- [ ] Switch locale in Settings, verify UI updates without restart
- [ ] Log out and log in, verify locale restored
- [ ] Test on multi-user device, verify locales independent
- [ ] View admin dashboard in Hindi, verify status labels translated
- [ ] Access request screen in Gujarati, verify all labels translated
- [ ] Download PDF, verify English-only notice displayed
- [ ] View AI summary in Hindi, check medical terminology

## Architecture Notes

### Locale Provider Hierarchy

```
AppLocalizations.of(context)
  â””â”€> appLocaleProvider (authenticated users)
      â””â”€> currentUserProvider.preferredLocale
          â””â”€> Database: users.preferred_locale

Special case: Registration screen
  â””â”€> Localizations.override(locale: Locale(_locale))
      â””â”€> Local widget state before account creation
```

### Backend Locale Flow

```
HTTP Request
  â””â”€> Header: Accept-Language (optional)
  â””â”€> JWT: user.preferred_locale (authenticated)
      â””â”€> normalize_locale()
          â””â”€> Returns: 'en', 'hi', 'gu', or 'en' (fallback)
              â””â”€> Used for: AI translation, PDF chrome, email content
```

### Translation Caching

- Backend caches AI translations in `ai_summaries` table
- `canonical_content`: Always English
- `translated_content`: Hindi/Gujarati if available
- `translation_locale`: Target locale of translation
- `used_fallback`: Boolean flag for UI indicator

## Troubleshooting

### "Form stays in English after selecting Hindi"

**Check:** Is this the registration screen or elsewhere?
- Registration screen: Should work with `Localizations.override`
- Other screens: Verify user's `preferred_locale` in database
- Try: Log out and log in to refresh locale provider

### "Status labels showing in English"

**Check:** Are helper functions being used?
```dart
// Wrong:
Text(status.label)

// Right:
Text(accessStatusLabel(l10n, status))
```

**Fix:** Import `enum_labels.dart` and use helper functions

### "Gujarati text shows as boxes in PDF"

**Expected:** This is the current known limitation. PDFs are English-only until font support is implemented.

**Verify:** User should see notice in UI before downloading PDF

### "Translation numbers don't match original"

**Good:** Safety validation working correctly. Translation was rejected.

**Check:** Backend logs for numeric validation failures

**Action:** Review AI translation prompt for number preservation

## Resources

- **Flutter Internationalization:** https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization
- **ARB Specification:** https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification
- **ReportLab Fonts:** https://docs.reportlab.com/reportlab/userguide/ch3_fonts/
- **Noto Fonts:** https://fonts.google.com/noto
- **ICU Message Format:** https://unicode-org.github.io/icu/userguide/format_parse/messages/

## Support

For localization issues or questions:
1. Check this documentation first
2. Review existing ARB files for examples
3. Run automated tests to verify changes
4. For medical translation concerns, escalate to clinical review

---

**Remember:** Medical translations are safety-critical. When in doubt, consult a qualified medical professional fluent in the target language.
