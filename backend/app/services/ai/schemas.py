"""Output shapes for each AI service. Responses that don't match are rejected (Try Again)."""

from pydantic import BaseModel, Field


class _Lenient(BaseModel):
    model_config = {"extra": "ignore"}


class RelevantValue(_Lenient):
    name: str
    value: str
    unit: str | None = None
    reference_range: str | None = None
    note: str | None = None


class ReportSummaryOutput(_Lenient):
    report_information: str = ""
    summary: str
    key_findings: list[str] = Field(default_factory=list)
    relevant_values: list[RelevantValue] = Field(default_factory=list)
    observed_trends: list[str] = Field(default_factory=list)
    interpretation: str = ""
    questions_for_doctor: list[str] = Field(default_factory=list)
    limitations: list[str] = Field(default_factory=list)


class ExtractedLabValue(_Lenient):
    test: str
    value: str
    unit: str | None = None
    printed_name: str | None = None


class LabValuesOutput(_Lenient):
    values: list[ExtractedLabValue] = Field(default_factory=list)


class TrendPoint(_Lenient):
    value: str
    date: str | None = None
    report_code: str | None = None


class ObservedTrend(_Lenient):
    parameter: str
    earlier: TrendPoint | None = None
    latest: TrendPoint | None = None
    observed_change: str
    # Backend-computed after the AI response is parsed (see routers/ai.py); the AI never
    # supplies these and any value it guesses is overwritten. See report_values.classify_trend().
    direction: str = "unknown"
    category: str = "unknown"


class AllReportsSummaryOutput(_Lenient):
    summary: str
    observed_trends: list[ObservedTrend] = Field(default_factory=list)
    key_findings: list[str] = Field(default_factory=list)
    gaps: list[str] = Field(default_factory=list)
    interpretation: str = ""
    questions_for_doctor: list[str] = Field(default_factory=list)


class PatientSummaryOutput(_Lenient):
    # Quick-view fields (10-second clinical overview): kept short and prioritized.
    current_status: str
    key_findings: list[str] = Field(default_factory=list)
    trends: list[str] = Field(default_factory=list)
    attention_items: list[str] = Field(default_factory=list)
    recent_changes: list[str] = Field(default_factory=list)
    interpretation: str = ""
    # Detailed, per-category fields: shown only behind "View details".
    diabetes_history: str = ""
    recent_assessments: str = ""
    medical_reports: str = ""
    glucose_history: str = ""
    lifestyle_trends: str = ""
    medication_history: str = ""
    side_effects: str = ""
    doctor_visits: str = ""
    recent_developments: str = ""
    heart_history: str = ""


class PatientFriendlySummaryOutput(_Lenient):
    """Plain-language patient-facing summary. Independent generation from
    PatientSummaryOutput: same authorized record, different audience and wording."""

    overall: str
    standouts: list[str] = Field(default_factory=list)
    changes: list[str] = Field(default_factory=list)
    keep_in_mind: list[str] = Field(default_factory=list)
    discuss_with_doctor: list[str] = Field(default_factory=list)


class LifestyleOverview(_Lenient):
    activity: str = ""
    sleep: str = ""
    food: str = ""
    heart_rate: str = ""
    glucose: str = ""


class LifestyleOutput(_Lenient):
    headline: str
    overview: LifestyleOverview = Field(default_factory=LifestyleOverview)
    observations: list[str] = Field(default_factory=list)
    suggestions: list[str] = Field(default_factory=list)
    interpretation: str = ""


class AssessmentInterpretationOutput(_Lenient):
    interpretation: str
    contributing_patterns: list[str] = Field(default_factory=list)
    suggestions: list[str] = Field(default_factory=list)
