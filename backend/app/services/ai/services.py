"""The four separate AI services. Each has its own system instruction and output schema.

The diabetes ML model is NOT here: it lives in ml_service and is called through
DiabetesModelService. These services only summarize and interpret supplied data.
"""

import json

from .openrouter import AIResult, OpenRouterClient, Part
from .schemas import (
    AllReportsSummaryOutput,
    AssessmentInterpretationOutput,
    LabValuesOutput,
    LifestyleOutput,
    PatientFriendlySummaryOutput,
    PatientSummaryOutput,
    ReportSummaryOutput,
)

_SAFETY = (
    "Never diagnose with certainty. Never prescribe, stop or change medication or dosage. "
    "Never declare a medical emergency. Never predict when or whether the person will develop "
    "diabetes or heart disease. Never tell the person to ignore their doctor. A heart disease risk "
    "screening result (model susthiti-heart-v3) is a synthetic-data screening signal, never a "
    "diagnosis and never clinically validated; never say the person 'has heart disease', never "
    "call it confirmed, and never treat it as equivalent to the separate diabetes risk estimate or "
    "symptom-model classification. If information is missing, say it is not available rather than "
    "guessing. Respond with a single JSON object only."
)


def _json_block(label: str, data) -> Part:
    return Part(text=f"{label}:\n{json.dumps(data, default=str, ensure_ascii=False, indent=1)}")


class ReportSummaryService:
    """AI module #1: 'What does this particular report say?'"""

    PROMPT_VERSION = "report-summary-v1"

    SYSTEM_INSTRUCTION = (
        "You are summarizing a single medical report for informational purposes inside SUSTHITI, "
        "a diabetes-focused health record app. Do not invent values. Do not diagnose. Use only "
        "the supplied report information. Clearly distinguish observed findings (what the report "
        "states) from interpretation (your cautious reading), and put interpretation only in the "
        "'interpretation' field. Only describe trends that appear within this report itself. "
        + _SAFETY
        + " JSON shape: {\"report_information\": str, \"summary\": str, \"key_findings\": [str], "
        "\"relevant_values\": [{\"name\": str, \"value\": str, \"unit\": str|null, "
        "\"reference_range\": str|null, \"note\": str|null}], \"observed_trends\": [str], "
        "\"interpretation\": str, \"questions_for_doctor\": [str], \"limitations\": [str]}"
    )

    def __init__(self, client: OpenRouterClient):
        self.client = client

    def summarize(self, metadata: dict, file_bytes: bytes, mime_type: str) -> AIResult:
        parts = [
            _json_block("Report metadata recorded in SUSTHITI", metadata),
            Part(data=file_bytes, mime_type=mime_type),
            Part(text="Summarize the attached original report."),
        ]
        return self.client.generate_json(self.SYSTEM_INSTRUCTION, parts, ReportSummaryOutput, prompt_version=self.PROMPT_VERSION)


class LabValuesExtractionService:
    """Copies specific results from a report exactly as printed (used for scans and photos, which
    have no text to read). It never interprets or estimates; SUSTHITI re-checks every value."""

    PROMPT_VERSION = "lab-values-extraction-v1"

    SYSTEM_INSTRUCTION = (
        "You read one medical laboratory report and copy specific test results exactly as printed. "
        "Only these tests: hba1c (glycated haemoglobin), fasting_glucose (fasting blood/plasma glucose or sugar), "
        "random_glucose (random blood/plasma glucose or sugar), ogtt_2h (the 2-hour glucose of an oral glucose "
        "tolerance test; NOT post-prandial or after-meal glucose). For each of these that is clearly present, return "
        "{\"test\": one of the four keys, \"value\": the patient's result digits exactly as printed, \"unit\": the unit "
        "exactly as printed or null, \"printed_name\": the test name as printed}. Never return reference ranges, "
        "cut-offs, interpretation tables or estimated average glucose. Leave out anything not clearly present. Never "
        "estimate, round or calculate. Respond with a single JSON object only. JSON shape: {\"values\": [...]}"
    )

    def __init__(self, client: OpenRouterClient):
        self.client = client

    def extract(self, file_bytes: bytes, mime_type: str) -> AIResult:
        parts = [Part(data=file_bytes, mime_type=mime_type), Part(text="Copy the requested results from the attached report.")]
        return self.client.generate_json(self.SYSTEM_INSTRUCTION, parts, LabValuesOutput, prompt_version=self.PROMPT_VERSION)


class AllReportsSummaryService:
    """'What does the patient's collection of reports show over time?'"""

    PROMPT_VERSION = "all-reports-summary-v2"

    SYSTEM_INSTRUCTION = (
        "You are reviewing a patient's authorized collection of medical reports together, in "
        "chronological order, for informational purposes. Identify only trends that are directly "
        "supported by values in at least two supplied reports, citing each value's report code "
        "and report date (the medical date, not the upload date). If a trend cannot be "
        "established, list it under 'gaps'. Do not invent values. Do not diagnose. Clearly "
        "separate observed information from interpretation. In 'observed_change', only describe "
        "what the values were and how they changed (e.g. 'rose from 7.1% to 8.3%'); do not say "
        "whether the change is good, bad, an improvement, or a worsening -- a direction label is "
        "computed separately from the values you cite, not from your wording. "
        + _SAFETY
        + " JSON shape: {\"summary\": str, \"observed_trends\": [{\"parameter\": str, "
        "\"earlier\": {\"value\": str, \"date\": str, \"report_code\": str}, \"latest\": {\"value\": "
        "str, \"date\": str, \"report_code\": str}, \"observed_change\": str}], \"key_findings\": "
        "[str], \"gaps\": [str], \"interpretation\": str, \"questions_for_doctor\": [str]}"
    )

    def __init__(self, client: OpenRouterClient):
        self.client = client

    def summarize(self, reports: list[dict]) -> AIResult:
        """reports: chronological list of {metadata, individual_summary?, file_bytes?, mime_type?}."""
        parts: list[Part] = [Part(text=f"{len(reports)} reports follow in chronological order of report date.")]
        for index, report in enumerate(reports, start=1):
            parts.append(_json_block(f"Report {index} metadata", report["metadata"]))
            if report.get("individual_summary"):
                parts.append(_json_block(f"Report {index} stored AI summary (derived from the original)", report["individual_summary"]))
            if report.get("file_bytes") is not None:
                parts.append(Part(data=report["file_bytes"], mime_type=report["mime_type"]))
            elif not report.get("individual_summary"):
                parts.append(Part(text=f"Report {index}: original file not included (size limit); only metadata is available."))
        return self.client.generate_json(self.SYSTEM_INSTRUCTION, parts, AllReportsSummaryOutput, prompt_version=self.PROMPT_VERSION)


class PatientSummaryService:
    """Longitudinal summary across all authorized patient information (useful for a new doctor).

    Output is prioritized for a clinician to read in about 10 seconds: a handful of short,
    high-signal fields come first (see JSON shape), with the full per-category detail kept
    for a secondary "view details" read.
    """

    PROMPT_VERSION = "patient-summary-v3"

    SYSTEM_INSTRUCTION = (
        "Summarize the authorized longitudinal patient information for a clinician. Preserve "
        "chronology and dates. Do not invent missing events; write 'No records available' for "
        "empty sections. Clearly distinguish documented medical information (doctor visits, "
        "prescriptions, reports, recorded data, ML model classifications and screening results) "
        "from AI interpretation, which goes only in the 'interpretation' field. Attribute "
        "prescriptions and visits to the doctor who created them. The diabetes model output "
        "('future_diabetes_risk_assessments', 'earlier_symptom_model_assessments') is a "
        "classification of symptom/risk-factor inputs, not a diagnosis or a future-onset "
        "prediction. The heart disease screening output ('heart_risk_assessments') is a separate "
        "synthetic-data screening model (susthiti-heart-v3): report its screening_score_percent "
        "and risk_level as a documented screening result only -- never as a diagnosis, never as "
        "clinically validated, and never merged with or compared to the diabetes output as if "
        "they measured the same thing. "
        "Prioritize the following five fields for a fast clinical read: 'current_status' is only "
        "1-2 sentences on the patient's current documented state. 'key_findings' lists important "
        "abnormal or clinically relevant documented findings. 'trends' states improving/stable/"
        "worsening only when at least two data points genuinely support it; otherwise omit. "
        "'attention_items' lists documented items needing review or follow-up only -- never a "
        "treatment instruction, medication change, dosage, or invented urgency. 'recent_changes' "
        "lists new reports, symptoms, medication changes or notes since the last significant "
        "event. Keep each of these five fields terse (bullet-length), not paragraphs. "
        + _SAFETY
        + " JSON shape: {\"current_status\": str, \"key_findings\": [str], \"trends\": [str], "
        "\"attention_items\": [str], \"recent_changes\": [str], \"interpretation\": str, "
        "\"diabetes_history\": str, \"recent_assessments\": str, \"medical_reports\": str, "
        "\"glucose_history\": str, \"lifestyle_trends\": str, \"medication_history\": str, "
        "\"side_effects\": str, \"doctor_visits\": str, \"recent_developments\": str, "
        "\"heart_history\": str}"
    )

    def __init__(self, client: OpenRouterClient):
        self.client = client

    def summarize(self, record: dict) -> AIResult:
        return self.client.generate_json(
            self.SYSTEM_INSTRUCTION, [_json_block("Authorized patient record", record)], PatientSummaryOutput, prompt_version=self.PROMPT_VERSION
        )


class PatientFriendlySummaryService:
    """Patient-facing health summary: same authorized record as PatientSummaryService, but a
    separate generation aimed at a non-clinical reader -- plain language, short, and no
    clinical detail section. Exact documented values/units/ranges are never altered; only the
    narration is simplified."""

    PROMPT_VERSION = "patient-friendly-summary-v2"

    SYSTEM_INSTRUCTION = (
        "Summarize the authorized patient health record directly for the patient themselves, in "
        "plain, everyday language. Avoid medical jargon; when a medical term is necessary, "
        "briefly explain it in parentheses (for example, write 'Your LDL cholesterol is higher "
        "than the laboratory reference target, while HDL cholesterol is lower' rather than "
        "'Elevated LDL-C with reduced HDL-C'). Never change a documented value, unit, reference "
        "range or test name -- only the explanation around it may be simplified. Do not invent "
        "missing information; omit a field or say nothing is recorded rather than guessing. If "
        "'heart_risk_assessments' is present, describe it plainly as a screening result from a "
        "research/software model (not a lab test, not a diagnosis) -- for example, 'A heart "
        "disease screening tool gave a [low/moderate/high] risk signal based on the information "
        "provided' -- and never say the person 'has heart disease' or that it is confirmed. "
        "'overall' is 1-2 short sentences on the current documented status. 'standouts' lists "
        "important findings or changes in plain language. 'changes' lists what has changed "
        "recently in the records. 'keep_in_mind' lists neutral, informational points from the "
        "records (not advice). 'discuss_with_doctor' lists only documented items worth raising "
        "with a doctor -- never a treatment instruction, medication change, dosage, or invented "
        "urgency. "
        + _SAFETY
        + " JSON shape: {\"overall\": str, \"standouts\": [str], \"changes\": [str], "
        "\"keep_in_mind\": [str], \"discuss_with_doctor\": [str]}"
    )

    def __init__(self, client: OpenRouterClient):
        self.client = client

    def summarize(self, record: dict) -> AIResult:
        return self.client.generate_json(
            self.SYSTEM_INSTRUCTION, [_json_block("Authorized patient record", record)], PatientFriendlySummaryOutput, prompt_version=self.PROMPT_VERSION
        )


class LifestyleAIService:
    """Lifestyle analysis and suggestions; also the forward-looking interpretation of an assessment."""

    PROMPT_VERSION = "lifestyle-v2"
    INTERPRETATION_PROMPT_VERSION = "assessment-interpretation-v1"
    HEART_INTERPRETATION_PROMPT_VERSION = "heart-assessment-interpretation-v1"

    SYSTEM_INSTRUCTION = (
        "Analyze the supplied lifestyle trends (activity, sleep, heart rate, food log, glucose, "
        "report context) of a person using a diabetes-focused health app. The data may also "
        "include 'latest_heart_risk_screening', a separate synthetic-data screening model result "
        "(susthiti-heart-v3, never a diagnosis) -- you may mention it as context but never as a "
        "lab value or confirmed condition. Provide general, sustainable lifestyle suggestions. Do "
        "not prescribe medication. Do not diagnose. Do not claim certainty. Only compare against a "
        "recent average when the data includes enough days to support it. The supplied data may "
        "include documented allergies and doctor-recorded restrictions: never suggest a food, "
        "activity or substance that conflicts with either of them, and do not repeat them back as "
        "if they were your own medical advice. "
        + _SAFETY
        + " JSON shape: {\"headline\": str, \"overview\": {\"activity\": str, \"sleep\": str, "
        "\"food\": str, \"heart_rate\": str, \"glucose\": str}, \"observations\": [str], "
        "\"suggestions\": [str], \"interpretation\": str}"
    )

    INTERPRETATION_INSTRUCTION = (
        "You explain a diabetes symptom-model classification in the context of the person's "
        "recent lifestyle and glucose data. The model classifies current symptom patterns; it "
        "does NOT predict future onset, so never state a timeframe or a probability of developing "
        "diabetes. You may say that if unhealthy patterns continue they may increase future risk "
        "of type 2 diabetes. Use calm, non-alarming language and recommend discussing results "
        "with a doctor. The supplied data may include documented allergies and doctor-recorded "
        "restrictions: never suggest anything that conflicts with either of them. "
        + _SAFETY
        + " JSON shape: {\"interpretation\": str, \"contributing_patterns\": [str], \"suggestions\": [str]}"
    )

    HEART_INTERPRETATION_INSTRUCTION = (
        "You explain a heart disease risk SCREENING result in the context of the person's recent "
        "lifestyle and vitals data. The result comes from susthiti-heart-v3, a model trained on a "
        "20,000-row SYNTHETIC dataset for software/screening purposes -- it is NOT a clinical "
        "diagnosis, NOT clinically validated, and must never be stated with diagnostic certainty. "
        "Never say the person 'has heart disease' or that heart disease is 'confirmed'; refer to "
        "it only as a screening signal or risk signal (e.g. 'the screening model produced an "
        "elevated risk signal based on the information provided'). Never predict when or whether "
        "the person will develop heart disease. Use calm, non-alarming language and recommend "
        "discussing the result with a doctor. The supplied data may include documented allergies "
        "and doctor-recorded restrictions: never suggest anything that conflicts with either of "
        "them. "
        + _SAFETY
        + " JSON shape: {\"interpretation\": str, \"contributing_patterns\": [str], \"suggestions\": [str]}"
    )

    def __init__(self, client: OpenRouterClient):
        self.client = client

    def suggest(self, lifestyle: dict) -> AIResult:
        return self.client.generate_json(
            self.SYSTEM_INSTRUCTION, [_json_block("Lifestyle data", lifestyle)], LifestyleOutput, prompt_version=self.PROMPT_VERSION
        )

    def interpret_assessment(self, assessment: dict, lifestyle: dict) -> AIResult:
        return self.client.generate_json(
            self.INTERPRETATION_INSTRUCTION,
            [_json_block("Model assessment", assessment), _json_block("Recent lifestyle context", lifestyle)],
            AssessmentInterpretationOutput,
            prompt_version=self.INTERPRETATION_PROMPT_VERSION,
        )

    def interpret_heart_assessment(self, assessment: dict, lifestyle: dict) -> AIResult:
        """Mirrors interpret_assessment() for the heart screening model, as its own method (not
        a generalization of the diabetes one) so diabetes interpretation behaviour is untouched."""
        return self.client.generate_json(
            self.HEART_INTERPRETATION_INSTRUCTION,
            [_json_block("Heart risk screening result", assessment), _json_block("Recent lifestyle context", lifestyle)],
            AssessmentInterpretationOutput,
            prompt_version=self.HEART_INTERPRETATION_PROMPT_VERSION,
        )


_client: OpenRouterClient | None = None


def get_ai_client() -> OpenRouterClient:
    global _client
    if _client is None:
        _client = OpenRouterClient()
    return _client


def set_ai_client(client: OpenRouterClient | None) -> None:
    global _client
    _client = client
