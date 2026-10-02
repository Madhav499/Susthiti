"""Deterministic, auditable safety checks run on AI output after schema validation and
before storage. This is the second net, not the only one: the `_SAFETY` instruction in
services.py already asks the model not to do these things; this module verifies, in code,
that it didn't. Kept deterministic (regex/keyword) rather than a second AI "judge" call —
consistent with the rest of SUSTHITI's design, where the backend computes and verifies
facts and AI only narrates them (see services/lifestyle_data.py's trend math).

Never raises. check_output() returns a list of violation reason codes (empty = passed);
the caller (routers/ai.py's _store()) decides what to do with a non-empty list.
"""

import re

# Fields where the AI is speaking in its own voice (interpretation/advice), as opposed to
# fields meant to recite documented, supplied facts (e.g. "diabetes_history", "medical_reports").
# Some checks only make sense scoped to these — checking everywhere would also catch a
# legitimate restatement of the patient's own recorded history (e.g. a past visit's
# "diagnosed with hypertension"), which is not an AI diagnosis, just a documented fact.
_ADVICE_FIELDS = {"interpretation", "suggestions", "observations", "contributing_patterns", "questions_for_doctor"}


def _patterns(*phrases: str) -> list[re.Pattern]:
    return [re.compile(p, re.I) for p in phrases]


# category -> compiled trigger patterns. One list per category keeps coverage auditable
# and easy to extend with a one-line addition.
_PATTERNS: dict[str, list[re.Pattern]] = {
    "medication_dosage": _patterns(
        r"\btake\s+\d+(\.\d+)?\s*(mg|mcg|µg|ml|units?)\b",
        r"\b(increase|decrease|double|halve|reduce)\s+(your\s+)?(?:\w+\s+){0,2}(dose|dosage)\b",
        r"\bstop\s+taking\b",
        r"\bstart\s+taking\b",
    ),
    "supplement_dosage": _patterns(
        r"\btake\s+\d+(\.\d+)?\s*(iu|mg|mcg|g)\s+of\b",
        r"\b\d+\s*(tablets?|capsules?)\s+of\b",
    ),
    "emergency_declaration": _patterns(
        r"\bthis\s+is\s+an?\s+emergency\b",
        r"\b(go\s+to|call)\s+(the\s+)?(er|emergency\s+room|ambulance|911|112)\b",
        r"\bseek\s+emergency\s+(care|treatment|attention)\s+immediately\b",
    ),
    "numeric_target": _patterns(
        r"\bwalk\s+(exactly\s+)?[\d,]+\s*steps\b",
        r"\bdrink\s+\d+(\.\d+)?\s*(litres?|liters?|l|ml)\s+of\s+water\b",
        r"\beat\s+(exactly\s+)?[\d,]+\s*calories\b",
    ),
    "future_onset_claim": _patterns(
        r"\bwill\s+develop\s+diabetes\b",
        r"\d+\s*%\s+chance\s+of\s+developing\b",
        r"\bwithin\s+\d+\s+(years?|months?)\s+you\s+will\b",
    ),
    # Scoped (see _SCOPED below): "you have diabetes" is only a problem when it's the AI's
    # own claim, not when a field is reciting an actual documented diagnosis from records.
    "diagnosis_certainty": _patterns(
        r"\byou\s+(have|are)\s+(?:\w+\s+){0,2}diabet(es|ic)\b",
        r"\bthis\s+confirms\s+(that\s+)?you\b",
        r"\byou\s+definitely\s+have\b",
    ),
}

_SCOPED: dict[str, set[str]] = {"diagnosis_certainty": _ADVICE_FIELDS}

# Allergy/restriction-conflict keyword matching: short, generic words are excluded so a
# documented restriction like "no high-intensity exercise" matches on "intensity", not on
# the near-meaningless "high". Deliberately simple substring/stem matching, not synonym
# expansion — a known v1 limitation, documented in AI_ARCHITECTURE.md.
_CONFLICT_STOPWORDS = {
    "avoid", "avoiding", "without", "and", "or", "food", "foods", "diet", "diets",
    "exercise", "activity", "daily", "please", "high", "stop", "limit", "reduce",
}
_NEGATORS = ("avoid", "don't", "do not", "no ", "not ", "without", "stop", "skip", "limit", "reduce", "cut down on", "cut back on")


def _strings(value, field: str | None = None):
    """Yields (field_name, text) for every string leaf in a nested dict/list structure."""
    if isinstance(value, str):
        yield field, value
    elif isinstance(value, dict):
        for key, v in value.items():
            yield from _strings(v, key)
    elif isinstance(value, list):
        for item in value:
            yield from _strings(item, field)


def _keywords(phrase: str) -> list[str]:
    words = re.findall(r"[a-z0-9]+", phrase.lower())
    return [w for w in words if len(w) >= 5 and w not in _CONFLICT_STOPWORDS]


def _mentioned_without_negation(text: str, keyword_stem: str) -> bool:
    for match in re.finditer(re.escape(keyword_stem), text):
        window = text[max(0, match.start() - 40):match.start()]
        if any(neg in window for neg in _NEGATORS):
            continue
        return True
    return False


def _allergy_or_restriction_conflict(leaves: list[tuple[str | None, str]], context: dict | None) -> bool:
    if not context:
        return False
    terms = list(context.get("allergies") or []) + list(context.get("doctor_restrictions") or [])
    if not terms:
        return False
    advice_text = " ".join(text for field, text in leaves if field in _ADVICE_FIELDS).lower()
    if not advice_text:
        return False
    for term in terms:
        for keyword in _keywords(term):
            if _mentioned_without_negation(advice_text, keyword.rstrip("s")):
                return True
    return False


def check_output(kind: str, content: dict, context: dict | None = None) -> list[str]:
    """Scans a schema-validated AIResult.content for unsafe patterns. `kind` is the
    AISummary kind (e.g. "lifestyle", "individual_report"); `context` is the structured
    data the AI was given, when available, used only for the allergy/restriction check."""
    leaves = list(_strings(content))
    violations: list[str] = []
    for category, patterns in _PATTERNS.items():
        scope = _SCOPED.get(category)
        candidates = leaves if scope is None else [(f, t) for f, t in leaves if f in scope]
        if any(pattern.search(text) for _, text in candidates for pattern in patterns):
            violations.append(category)
    if _allergy_or_restriction_conflict(leaves, context):
        violations.append("allergy_or_restriction_conflict")
    return violations
