"""The four separate AI services. Each has its own system instruction and output schema.

The diabetes ML model is NOT here: it lives in ml_service and is called through
DiabetesModelService. These services only summarize and interpret supplied data.
"""

import json

from .gemini import AIResult, GeminiClient, Part
from .schemas import (
    AllReportsSummaryOutput,
    AssessmentInterpretationOutput,
    LabValuesOutput,
    LifestyleOutput,
    PatientSummaryOutput,
    ReportSummaryOutput,
)

_SAFETY = (
    "Never diagnose with certainty. Never prescribe, stop or change medication or dosage. "
    "Never declare a medical emergency. Never predict when or whether the person will develop "
    "diabetes. Never tell the person to ignore their doctor. If information is missing, say it is "
    "not available rather than guessing. Respond with a single JSON object only."
)


def _json_block(label: str, data) -> Part:
    return Part(text=f"{label}:\n{json.dumps(data, default=str, ensure_ascii=False, indent=1)}")


class ReportSummaryService:
    """AI module #1: 'What does this particular report say?'"""

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

    def __init__(self, client: GeminiClient):
        self.client = client

    def summarize(self, metadata: dict, file_bytes: bytes, mime_type: str) -> AIResult:
        parts = [
            _json_block("Report metadata recorded in SUSTHITI", metadata),
            Part(data=file_bytes, mime_type=mime_type),
            Part(text="Summarize the attached original report."),
        ]
        return self.client.generate_json(self.SYSTEM_INSTRUCTION, parts, ReportSummaryOutput)


class LabValuesExtractionService:
    """Copies specific results from a report exactly as printed (used for scans and photos, which
    have no text to read). It never interprets or estimates; SUSTHITI re-checks every value."""

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

    def __init__(self, client: GeminiClient):
        self.client = client

    def extract(self, file_bytes: bytes, mime_type: str) -> AIResult:
        parts = [Part(data=file_bytes, mime_type=mime_type), Part(text="Copy the requested results from the attached report.")]
        return self.client.generate_json(self.SYSTEM_INSTRUCTION, parts, LabValuesOutput)


class AllReportsSummaryService:
    """'What does the patient's collection of reports show over time?'"""

    SYSTEM_INSTRUCTION = (
        "You are reviewing a patient's authorized collection of medical reports together, in "
        "chronological order, for informational purposes. Identify only trends that are directly "
        "supported by values in at least two supplied reports, citing each value's report code "
        "and report date (the medical date, not the upload date). If a trend cannot be "
        "established, list it under 'gaps'. Do not invent values. Do not diagnose. Clearly "
        "separate observed information from interpretation. "
        + _SAFETY
        + " JSON shape: {\"summary\": str, \"observed_trends\": [{\"parameter\": str, "
        "\"earlier\": {\"value\": str, \"date\": str, \"report_code\": str}, \"latest\": {\"value\": "
        "str, \"date\": str, \"report_code\": str}, \"observed_change\": str}], \"key_findings\": "
        "[str], \"gaps\": [str], \"interpretation\": str, \"questions_for_doctor\": [str]}"
    )

    def __init__(self, client: GeminiClient):
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
        return self.client.generate_json(self.SYSTEM_INSTRUCTION, parts, AllReportsSummaryOutput)


class PatientSummaryService:
    """Longitudinal summary across all authorized patient information (useful for a new doctor)."""

    SYSTEM_INSTRUCTION = (
        "Summarize the authorized longitudinal patient information for a clinician. Preserve "
        "chronology and dates. Do not invent missing events; write 'No records available' for "
        "empty sections. Clearly distinguish documented medical information (doctor visits, "
        "prescriptions, reports, recorded data, ML model classifications) from AI interpretation, "
        "which goes only in the 'interpretation' field. Attribute prescriptions and visits to the "
        "doctor who created them. The diabetes model output is a classification of symptom "
        "inputs, not a diagnosis or a future-onset prediction. "
        + _SAFETY
        + " JSON shape: {\"patient_overview\": str, \"diabetes_history\": str, "
        "\"recent_assessments\": str, \"medical_reports\": str, \"relevant_trends\": str, "
        "\"glucose_history\": str, \"lifestyle_trends\": str, \"medication_history\": str, "
        "\"side_effects\": str, \"doctor_visits\": str, \"recent_developments\": str, "
        "\"items_to_discuss\": [str], \"interpretation\": str}"
    )

    def __init__(self, client: GeminiClient):
        self.client = client

    def summarize(self, record: dict) -> AIResult:
        return self.client.generate_json(
            self.SYSTEM_INSTRUCTION, [_json_block("Authorized patient record", record)], PatientSummaryOutput
        )


class LifestyleAIService:
    """Lifestyle analysis and suggestions; also the forward-looking interpretation of an assessment."""

    SYSTEM_INSTRUCTION = (
        "Analyze the supplied lifestyle trends (activity, sleep, heart rate, food log, glucose, "
        "report context) of a person using a diabetes-focused health app. Provide general, "
        "sustainable lifestyle suggestions. Do not prescribe medication. Do not diagnose. Do not "
        "claim certainty. Only compare against a recent average when the data includes enough "
        "days to support it. "
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
        "with a doctor. "
        + _SAFETY
        + " JSON shape: {\"interpretation\": str, \"contributing_patterns\": [str], \"suggestions\": [str]}"
    )

    def __init__(self, client: GeminiClient):
        self.client = client

    def suggest(self, lifestyle: dict) -> AIResult:
        return self.client.generate_json(
            self.SYSTEM_INSTRUCTION, [_json_block("Lifestyle data", lifestyle)], LifestyleOutput
        )

    def interpret_assessment(self, assessment: dict, lifestyle: dict) -> AIResult:
        return self.client.generate_json(
            self.INTERPRETATION_INSTRUCTION,
            [_json_block("Model assessment", assessment), _json_block("Recent lifestyle context", lifestyle)],
            AssessmentInterpretationOutput,
        )


_client: GeminiClient | None = None


def get_ai_client() -> GeminiClient:
    global _client
    if _client is None:
        _client = GeminiClient()
    return _client


def set_ai_client(client: GeminiClient | None) -> None:
    global _client
    _client = client
