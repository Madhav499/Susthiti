"""Viewer-language rendering of an already-generated, already safety-checked AI summary.

Design: generation always happens in English first (services.py, unchanged) and that
canonical content is what safety.check_output() validates -- this module runs strictly
AFTER that, and only when the viewer's preferred_locale isn't English. It is a translation
pass, never a second opinion: it must never add, remove, or re-derive a clinical
conclusion, so every numeric/structured field below is removed from what gets sent to the
model and spliced back onto the result unchanged, rather than trusting the model's promise
to "leave it alone". A translated leaf that doesn't carry the same numbers as its English
source is reverted to the English source, field by field, rather than ever shown as a
silently-wrong translation (callers see `used_fallback` and can tell the viewer).
"""

import json
import re
from collections import Counter

from pydantic import BaseModel

from .openrouter import OpenRouterClient, Part
from .schemas import (
    AllReportsSummaryOutput,
    AssessmentInterpretationOutput,
    LifestyleOutput,
    PatientFriendlySummaryOutput,
    PatientSummaryOutput,
    ReportSummaryOutput,
)

LANGUAGE_NAMES = {"hi": "Hindi", "gu": "Gujarati"}

_SCHEMA_BY_KIND: dict[str, type[BaseModel]] = {
    "individual_report": ReportSummaryOutput,
    "all_reports": AllReportsSummaryOutput,
    "patient_summary": PatientSummaryOutput,
    "patient_friendly_summary": PatientFriendlySummaryOutput,
    "lifestyle": LifestyleOutput,
    "assessment_interpretation": AssessmentInterpretationOutput,
    "heart_interpretation": AssessmentInterpretationOutput,
}

_NUMBER_RE = re.compile(r"\d+(?:[.,]\d+)?")


class LocalizationUnavailable(Exception):
    pass


def supports_localization(kind: str) -> bool:
    return kind in _SCHEMA_BY_KIND


def _numbers(text: str) -> Counter:
    return Counter(m.replace(",", "") for m in _NUMBER_RE.findall(text))


def _translate_leaf(original: str, translated: object) -> tuple[str, bool]:
    """Returns (text_to_use, used_fallback). Falls back to the English original whenever the
    translated value isn't a non-empty string carrying the exact same numbers."""
    if not isinstance(translated, str) or not translated.strip():
        return original, bool(original)
    if _numbers(translated) != _numbers(original):
        return original, True
    return translated, False


def _translate_strings(original, translated) -> tuple[object, bool]:
    """Walks parallel (original, translated) structures (str / list / dict), keeping
    `translated`'s shape where it validates and falling back leaf-by-leaf on mismatch."""
    if isinstance(original, str):
        return _translate_leaf(original, translated)
    if isinstance(original, list):
        if not isinstance(translated, list) or len(translated) != len(original):
            return original, bool(original)
        any_fallback = False
        out = []
        for o, t in zip(original, translated):
            value, fell_back = _translate_strings(o, t)
            out.append(value)
            any_fallback = any_fallback or fell_back
        return out, any_fallback
    if isinstance(original, dict):
        if not isinstance(translated, dict):
            return original, bool(original)
        any_fallback = False
        out = {}
        for key, o in original.items():
            value, fell_back = _translate_strings(o, translated.get(key))
            out[key] = value
            any_fallback = any_fallback or fell_back
        return out, any_fallback
    return original, False


# Top-level fields that must reach the viewer byte-identical to the English generation:
# lab values, dates, codes and backend-computed trend direction/category. Never sent for
# translation, and always spliced back from the original regardless of what comes back.
_PRESERVE_TOP_LEVEL: dict[str, set[str]] = {
    "individual_report": {"relevant_values"},
    "all_reports": {"observed_trends"},
}


def _strip_preserved(content: dict, kind: str) -> tuple[dict, dict]:
    preserve_keys = _PRESERVE_TOP_LEVEL.get(kind, set())
    translatable = {k: v for k, v in content.items() if k not in preserve_keys}
    preserved = {k: content[k] for k in preserve_keys if k in content}
    if kind == "all_reports" and "observed_trends" in content:
        # The trend's own `observed_change` sentence is still worth translating; only the
        # structured parameter/values/dates/direction/category are pulled out and preserved.
        translatable["observed_trends"] = [
            {"parameter": t.get("parameter"), "observed_change": t.get("observed_change")}
            for t in (content.get("observed_trends") or [])
            if isinstance(t, dict)
        ]
    return translatable, preserved


def _restore_preserved(translated: dict, preserved: dict, kind: str) -> dict:
    out = dict(translated)
    if kind == "all_reports" and "observed_trends" in preserved:
        translated_trends = translated.get("observed_trends") or []
        restored = []
        for index, original_trend in enumerate(preserved["observed_trends"]):
            merged = dict(original_trend)
            if index < len(translated_trends) and isinstance(translated_trends[index], dict):
                text, _ = _translate_leaf(original_trend.get("observed_change") or "", translated_trends[index].get("observed_change"))
                merged["observed_change"] = text
            restored.append(merged)
        out["observed_trends"] = restored
    for key, value in preserved.items():
        if key == "observed_trends":
            continue
        out[key] = value
    return out


_INSTRUCTION_TEMPLATE = (
    "You translate structured medical-summary JSON from English into {language} for a reader "
    "in India. Translate every prose string value into natural, simple, everyday {language} that "
    "a patient with limited medical literacy can follow -- not overly formal or literary "
    "{language}. Keep internationally standard medical terms, test names and abbreviations "
    "unchanged (for example HbA1c, ECG, BMI, LDL, HDL): you may add a short plain-{language} "
    "explanation in parentheses the first time a term appears, but never remove or alter the "
    "term itself. Never change, translate, round, or drop any number, percentage, unit, date, "
    "medicine name, dosage, frequency, or duration -- copy these exactly as given, in their "
    "original digits and script. Never add information that is not in the source text, never "
    "remove a warning, a qualifier such as 'possible' or 'suspected', or a negation such as "
    "'no evidence of'. Preserve the exact JSON keys and array lengths of the input; translate "
    "only the string values. Respond with a single JSON object only, no commentary."
)


def localize_content(client: OpenRouterClient, kind: str, content: dict, locale: str) -> tuple[dict, bool]:
    """Returns (localized_content, used_fallback). Raises LocalizationUnavailable if the kind
    isn't supported or the AI call itself fails outright (caller falls back to English)."""
    schema = _SCHEMA_BY_KIND.get(kind)
    if schema is None:
        raise LocalizationUnavailable(f"No localization schema for kind={kind!r}")
    language = LANGUAGE_NAMES.get(locale)
    if language is None:
        raise LocalizationUnavailable(f"Unsupported locale={locale!r}")
    translatable, preserved = _strip_preserved(content, kind)
    instruction = _INSTRUCTION_TEMPLATE.format(language=language)
    parts = [Part(text=f"Source JSON (English):\n{json.dumps(translatable, ensure_ascii=False, indent=1)}")]
    result = client.generate_json(instruction, parts, schema, prompt_version=f"localize-{kind}-{locale}-v1")
    merged, any_fallback = _translate_strings(translatable, result.content)
    restored = _restore_preserved(merged, preserved, kind)
    return restored, any_fallback
