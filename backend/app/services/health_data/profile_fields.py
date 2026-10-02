"""The health profile: questions SUSTHITI keeps answers to (not tied to any one model).

Values use SUSTHITI's own vocabulary; a model's feature builder maps them to that model's
terms. Each answer is used for `fresh_days` after it was given (None: until changed), then it is
treated as unknown until the patient confirms it again.
"""

from dataclasses import dataclass, field
from typing import Any

BODY, MEDICAL, FAMILY, HABITS, SYMPTOMS = "body", "medical_history", "family_history", "habits", "symptoms"

GROUP_LABELS = {
    BODY: "Body measurements",
    MEDICAL: "Medical history",
    FAMILY: "Family history",
    HABITS: "Habits and lifestyle",
    SYMPTOMS: "Recent symptoms",
}


@dataclass(frozen=True)
class ProfileField:
    key: str
    group: str
    label: str
    kind: str  # number | yes_no | choice | list
    options: tuple[tuple[str, str], ...] = ()  # (value, label)
    unit: str | None = None
    min: float | None = None
    max: float | None = None
    fresh_days: int | None = None
    applies_to: str | None = None  # only asked for this sex ("Female")
    help: str | None = None
    extra: dict = field(default_factory=dict)

    def validate(self, value: Any) -> Any:
        """Returns the stored form of value, or raises ValueError. None means "not sure"."""
        if value is None:
            return None
        if self.kind == "yes_no":
            if isinstance(value, bool):
                return value
            raise ValueError(f"{self.label}: answer yes, no or not sure.")
        if self.kind == "choice":
            allowed = [v for v, _ in self.options]
            if value in allowed:
                return value
            raise ValueError(f"{self.label}: choose one of the listed options.")
        if self.kind == "list":
            if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
                raise ValueError(f"{self.label}: enter a list of short text items.")
            seen: list[str] = []
            for item in value:
                cleaned = " ".join(item.split()).strip()
                if not cleaned:
                    continue
                if len(cleaned) > 200:
                    raise ValueError(f"{self.label}: each item must be 200 characters or fewer.")
                if cleaned.lower() not in (s.lower() for s in seen):
                    seen.append(cleaned)
            if len(seen) > 20:
                raise ValueError(f"{self.label}: list up to 20 items.")
            return seen
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ValueError(f"{self.label} must be a number.")
        number = float(value)
        if (self.min is not None and number < self.min) or (self.max is not None and number > self.max):
            raise ValueError(f"{self.label} must be between {self.min:g} and {self.max:g} {self.unit or ''}".strip() + ".")
        return round(number, 1)

    def option_label(self, value: Any) -> str | None:
        return next((label for v, label in self.options if v == value), None)


FIELDS: tuple[ProfileField, ...] = (
    ProfileField("height_cm", BODY, "Height", "number", unit="cm", min=50, max=250),
    ProfileField("weight_kg", BODY, "Weight", "number", unit="kg", min=10, max=400, fresh_days=365),
    ProfileField("family_history_diabetes", FAMILY, "A parent, brother or sister has diabetes", "yes_no"),
    ProfileField("previous_prediabetes", MEDICAL, "A doctor has told you that you had prediabetes", "yes_no"),
    ProfileField("previous_gestational_diabetes", MEDICAL, "Diabetes during a pregnancy (gestational diabetes)", "yes_no", applies_to="Female"),
    ProfileField("hypertension", MEDICAL, "High blood pressure diagnosed by a doctor", "yes_no"),
    ProfileField("high_cholesterol", MEDICAL, "High cholesterol diagnosed by a doctor", "yes_no"),
    ProfileField("pcos", MEDICAL, "Polycystic ovary syndrome (PCOS)", "yes_no", applies_to="Female"),
    ProfileField("cardiovascular_disease", MEDICAL, "Heart or blood-vessel disease (e.g. heart attack, stroke)", "yes_no"),
    ProfileField("fatty_liver_disease", MEDICAL, "Fatty liver disease", "yes_no"),
    ProfileField("physical_activity_level", HABITS, "Physical activity", "choice",
                 (("low", "Low (little regular exercise)"), ("moderate", "Moderate"), ("high", "High (active most days)")), fresh_days=180,
                 help="Used only when your phone hasn't recorded enough daily steps."),
    ProfileField("sedentary_hours_per_day", HABITS, "Hours spent sitting on a typical day", "number", unit="h", min=0, max=24, fresh_days=180),
    ProfileField("diet_quality", HABITS, "Overall diet", "choice", (("good", "Good"), ("average", "Average"), ("poor", "Poor")), fresh_days=180),
    ProfileField("sugary_drink_frequency", HABITS, "Sugary drinks (soft drinks, sweetened juice, sweet tea)", "choice",
                 (("never_rarely", "Never or rarely"), ("1_3_per_week", "1–3 a week"), ("4_6_per_week", "4–6 a week"), ("daily", "Daily")), fresh_days=180),
    ProfileField("smoking_status", HABITS, "Smoking", "choice", (("never", "Never smoked"), ("former", "Used to smoke"), ("current", "Smoke now")), fresh_days=365),
    ProfileField("alcohol_frequency", HABITS, "Alcohol", "choice",
                 (("never", "Never"), ("occasionally", "Occasionally"), ("weekly", "Weekly"), ("frequent", "Several times a week or more")), fresh_days=365),
    ProfileField("stress_level", HABITS, "Stress in recent weeks", "choice", (("low", "Low"), ("moderate", "Moderate"), ("high", "High")), fresh_days=90),
    ProfileField("polyuria", SYMPTOMS, "Passing urine much more often than usual", "yes_no", fresh_days=90),
    ProfileField("polydipsia", SYMPTOMS, "Unusual or constant thirst", "yes_no", fresh_days=90),
    ProfileField("unexplained_weight_loss", SYMPTOMS, "Losing weight without trying", "yes_no", fresh_days=90),
    ProfileField("polyphagia", SYMPTOMS, "Unusually strong or constant hunger", "yes_no", fresh_days=90),
    ProfileField("allergies", MEDICAL, "Known allergies (medication, food or other)", "list",
                 help="Documented allergies are treated as authoritative and must never be contradicted by AI-generated suggestions."),
    ProfileField("doctor_restrictions", MEDICAL, "Doctor-documented restrictions", "list",
                 help="Recorded by a doctor only. Treated as authoritative and must never be contradicted by AI-generated suggestions."),
)

BY_KEY = {f.key: f for f in FIELDS}

# Fields only a doctor may write, even though a patient can read them. Enforced in
# routers/health_data.py's update_health_profile, not just by UI visibility.
DOCTOR_ONLY = {"doctor_restrictions"}
