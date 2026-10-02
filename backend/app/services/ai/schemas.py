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


class AllReportsSummaryOutput(_Lenient):
    summary: str
    observed_trends: list[ObservedTrend] = Field(default_factory=list)
    key_findings: list[str] = Field(default_factory=list)
    gaps: list[str] = Field(default_factory=list)
    interpretation: str = ""
    questions_for_doctor: list[str] = Field(default_factory=list)


class PatientSummaryOutput(_Lenient):
    patient_overview: str
    diabetes_history: str = ""
    recent_assessments: str = ""
    medical_reports: str = ""
    relevant_trends: str = ""
    glucose_history: str = ""
    lifestyle_trends: str = ""
    medication_history: str = ""
    side_effects: str = ""
    doctor_visits: str = ""
    recent_developments: str = ""
    items_to_discuss: list[str] = Field(default_factory=list)
    interpretation: str = ""


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
