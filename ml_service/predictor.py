"""Loads the supplied diabetes_all_age_gender_model.joblib once and runs predictions.

Nothing here substitutes another model or fabricates a result: if the model file is missing
or its expected inputs don't match the 16 features, the service reports itself unavailable.
The Yes/No and Gender encodings live in model/feature_config.json and must match the
training notebook (run verify_model.py against the dataset to confirm).
"""

import hashlib
import json
import logging
from dataclasses import dataclass
from pathlib import Path

import joblib
import pandas as pd

from schemas import FEATURES

log = logging.getLogger("ml_service")

BASE = Path(__file__).parent
DEFAULT_MODEL_PATH = BASE / "model" / "diabetes_all_age_gender_model.joblib"
DEFAULT_CONFIG_PATH = BASE / "model" / "feature_config.json"


class ModelNotReady(Exception):
    pass


@dataclass
class Prediction:
    prediction: str
    classification_probability: float | None
    model_version: str


def _is_raw_pipeline(model) -> bool:
    """True when the artifact is a Pipeline that encodes categorical strings itself."""
    try:
        from sklearn.compose import ColumnTransformer
        from sklearn.pipeline import Pipeline
        from sklearn.preprocessing import LabelEncoder, OneHotEncoder, OrdinalEncoder
    except ImportError:  # pragma: no cover
        return False
    if not isinstance(model, Pipeline):
        return False
    encoders = (ColumnTransformer, OneHotEncoder, OrdinalEncoder, LabelEncoder)
    return any(isinstance(step, encoders) for _, step in model.steps)


class DiabetesPredictor:
    def __init__(self, model_path: Path = DEFAULT_MODEL_PATH, config_path: Path = DEFAULT_CONFIG_PATH):
        self.model_path = Path(model_path)
        self.config = json.loads(Path(config_path).read_text())
        self.model = None
        self.error: str | None = None
        self.input_mode = self.config.get("input_mode", "auto")
        self.column_names: list[str] = list(FEATURES)
        self.version = self.config.get("model_version", "v1")

    def load(self) -> None:
        if not self.model_path.exists():
            self.error = f"Model file not found at {self.model_path.name}. Place the supplied .joblib in ml_service/model/."
            log.warning(self.error)
            return
        try:
            model = joblib.load(self.model_path)
        except Exception as exc:  # corrupt file / incompatible sklearn version
            self.error = f"Model could not be loaded ({type(exc).__name__}). Check the scikit-learn version used in the notebook."
            log.error(self.error)
            return
        if not hasattr(model, "predict"):
            self.error = "The loaded object has no predict() method."
            return
        names = getattr(model, "feature_names_in_", None)
        if names is not None:
            names = [str(n) for n in names]
            if sorted(names) != sorted(FEATURES):
                self.error = (
                    "The model expects different input columns than the 16 SUSTHITI features: "
                    f"{names}. Update feature_config.json to describe the notebook's preprocessing."
                )
                log.error(self.error)
                return
            self.column_names = names  # keep the model's own column order
        n_in = getattr(model, "n_features_in_", None)
        if n_in is not None and n_in != len(FEATURES):
            self.error = f"The model expects {n_in} inputs, but SUSTHITI supplies exactly {len(FEATURES)}."
            return
        if self.input_mode == "auto":
            self.input_mode = "raw" if _is_raw_pipeline(model) else "encoded"
        digest = hashlib.sha256(self.model_path.read_bytes()).hexdigest()[:8]
        self.version = f"{self.config.get('model_version', 'v1')}+{digest}"
        self.model = model
        self.error = None
        log.info("model loaded version=%s input_mode=%s", self.version, self.input_mode)

    @property
    def ready(self) -> bool:
        return self.model is not None

    def encode(self, features: dict) -> pd.DataFrame:
        if self.input_mode == "raw":
            row = {name: features[name] for name in self.column_names}
        else:
            yes_no = self.config["yes_no"]
            gender = self.config["gender"]
            row = {}
            for name in self.column_names:
                value = features[name]
                if name == "Age":
                    row[name] = int(value)
                elif name == "Gender":
                    row[name] = gender[value]
                else:
                    row[name] = yes_no[value]
        return pd.DataFrame([row], columns=self.column_names)

    def _label(self, raw) -> str:
        text = str(raw)
        if text in ("Positive", "Negative"):
            return text
        mapped = self.config["classes"].get(text)
        if mapped is None:
            raise ModelNotReady(f"Unrecognised model class {text!r}; update 'classes' in feature_config.json.")
        return mapped

    def predict(self, features: dict) -> Prediction:
        if not self.ready:
            raise ModelNotReady(self.error or "Model not loaded.")
        frame = self.encode(features)
        raw = self.model.predict(frame)[0]
        label = self._label(raw)
        probability = None
        if hasattr(self.model, "predict_proba"):
            proba = self.model.predict_proba(frame)[0]
            classes = list(getattr(self.model, "classes_", []))
            if raw in classes:
                probability = float(proba[classes.index(raw)])
        return Prediction(label, None if probability is None else round(probability, 4), self.version)
