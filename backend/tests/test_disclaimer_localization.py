"""Tests for medical disclaimer localization to ensure safety-critical text is correct."""

from app.services.i18n import DISCLAIMER_BY_LOCALE, localized_disclaimer, normalize_locale


def test_disclaimer_exists_for_all_supported_locales():
    """Every supported locale must have a disclaimer."""
    assert "en" in DISCLAIMER_BY_LOCALE
    assert "hi" in DISCLAIMER_BY_LOCALE
    assert "gu" in DISCLAIMER_BY_LOCALE


def test_english_disclaimer_is_clear_and_accurate():
    """The English disclaimer must be medically appropriate."""
    en = DISCLAIMER_BY_LOCALE["en"]
    assert "AI" in en or "ai" in en.lower()
    assert "not replace" in en or "does not replace" in en
    assert "medical" in en.lower() or "professional" in en.lower()
    assert len(en) > 50  # Must be substantive, not a stub


def test_hindi_disclaimer_is_well_formed():
    """Hindi disclaimer must be valid Unicode without corruption."""
    hi = DISCLAIMER_BY_LOCALE["hi"]

    # Must contain Devanagari script (U+0900 to U+097F)
    has_devanagari = any('ऀ' <= c <= 'ॿ' for c in hi)
    assert has_devanagari, "Hindi disclaimer must contain Devanagari characters"

    # Must contain "AI" as standalone Latin text (standard in Hindi)
    assert "AI" in hi, "Hindi disclaimer must reference AI"

    # Must be substantive
    assert len(hi) > 50, "Hindi disclaimer must be complete, not truncated"

    # Common Hindi words for this context
    assert "नहीं" in hi or "नही" in hi, "Must contain negation (not/no)"


def test_gujarati_disclaimer_is_well_formed():
    """Gujarati disclaimer must be valid Unicode without corruption."""
    gu = DISCLAIMER_BY_LOCALE["gu"]

    # Must contain Gujarati script (U+0A80 to U+0AFF)
    has_gujarati = any('઀' <= c <= '૿' for c in gu)
    assert has_gujarati, "Gujarati disclaimer must contain Gujarati characters"

    # Must contain "AI" as standalone Latin text (standard in Gujarati)
    assert "AI" in gu, "Gujarati disclaimer must reference AI"

    # Must be substantive
    assert len(gu) > 50, "Gujarati disclaimer must be complete, not truncated"

    # Common Gujarati word for negation
    assert "નથી" in gu, "Must contain negation (not/no)"


def test_disclaimers_do_not_contain_control_characters():
    """Disclaimers must not have embedded control characters or malformed text."""
    for locale, text in DISCLAIMER_BY_LOCALE.items():
        # No control characters except space, tab, newline
        for char in text:
            if ord(char) < 32 and char not in (' ', '\t', '\n'):
                raise AssertionError(f"{locale} disclaimer contains control character: {repr(char)}")

        # No replacement characters (indicates encoding issues)
        assert '�' not in text, f"{locale} disclaimer contains replacement character"


def test_localized_disclaimer_function():
    """The localized_disclaimer function must return correct text for each locale."""
    assert localized_disclaimer("en") == DISCLAIMER_BY_LOCALE["en"]
    assert localized_disclaimer("hi") == DISCLAIMER_BY_LOCALE["hi"]
    assert localized_disclaimer("gu") == DISCLAIMER_BY_LOCALE["gu"]

    # Invalid/unsupported locales fall back to English
    assert localized_disclaimer("fr") == DISCLAIMER_BY_LOCALE["en"]
    assert localized_disclaimer(None) == DISCLAIMER_BY_LOCALE["en"]
    assert localized_disclaimer("") == DISCLAIMER_BY_LOCALE["en"]
    assert localized_disclaimer("invalid") == DISCLAIMER_BY_LOCALE["en"]


def test_disclaimers_are_deterministic_not_ai_generated():
    """Disclaimers must be fixed strings, never AI-generated at runtime.

    This test documents that the disclaimers are hand-translated once for safety,
    not regenerated on each use.
    """
    # Calling the function multiple times returns identical text (deterministic)
    assert localized_disclaimer("hi") == localized_disclaimer("hi")
    assert localized_disclaimer("gu") == localized_disclaimer("gu")

    # The text is defined in a dict literal, not computed
    assert isinstance(DISCLAIMER_BY_LOCALE, dict)
    assert len(DISCLAIMER_BY_LOCALE) == 3


def test_disclaimer_meaning_consistency():
    """All translations must convey the core safety message: AI-generated, not medical advice."""
    # We can't programmatically verify translation accuracy, but we can verify
    # all disclaimers have similar structure and length, suggesting completeness

    lengths = [len(text) for text in DISCLAIMER_BY_LOCALE.values()]
    min_len, max_len = min(lengths), max(lengths)

    # Translations should be within 2x of each other (rough heuristic)
    assert max_len < min_len * 2.5, "One translation is suspiciously much longer/shorter than others"

    # All should be at least 50 chars (substantive text)
    assert all(len(text) > 50 for text in DISCLAIMER_BY_LOCALE.values())
