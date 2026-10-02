"""Client for the SUSTHITI Future Diabetes Risk API (v4.x), a private service only this backend
calls (ML_SERVICE_URL). It never produces or adjusts a prediction itself: it sends the model
features, then checks the reply is complete and consistent before anything is stored.

A future API version gets its own client class implementing DiabetesRiskApiClient; the rest
of SUSTHITI only depends on RiskPrediction.
"""

import logging
from dataclasses import dataclass
from typing import Any, Protocol

import httpx

from ... import errors
from ...config import get_settings
from .features import REPORT_FIELDS, SUPPORTED_MAJOR

log = logging.getLogger("susthiti.diabetes_risk")

CATEGORIES = ("Low", "Moderate", "High")
BASES = ("symptoms_and_risk_factors_only", "symptoms_and_available_health_report")


@dataclass(frozen=True)
class RiskPrediction:
    success: bool
    risk_percent: float
    risk_category: str
    risk_thresholds: dict
    prediction: int
    prediction_label: str
    prediction_threshold: str | None
    prediction_basis: str
    report_available: bool
    report_fields_present: list[str]
    bmi: float | None
    model_version: str
    warning: str | None


class DiabetesRiskApiClient(Protocol):
    def health(self) -> dict: ...

    def predict(self, data: dict[str, Any]) -> RiskPrediction: ...


def version_major(version: str | None) -> int | None:
    try:
        return int(str(version).split(".")[0])
    except (TypeError, ValueError):
        return None


class DiabetesRiskApiV4Client:
    def __init__(self, base_url: str | None = None, transport: httpx.BaseTransport | None = None):
        settings = get_settings()
        self.base_url = (base_url or settings.ml_service_url).rstrip("/")
        self.timeout = settings.ml_service_timeout_seconds
        self.transport = transport

    def _request(self, method: str, path: str, **kwargs) -> httpx.Response:
        try:
            with httpx.Client(timeout=self.timeout, transport=self.transport) as client:
                return client.request(method, f"{self.base_url}{path}", **kwargs)
        except httpx.TimeoutException:
            raise errors.ml_timeout()
        except httpx.HTTPError:  # refused, DNS, network
            raise errors.ml_unavailable("The diabetes assessment service is unavailable right now. Please try again later.")

    def health(self) -> dict:
        """Confirms the service is up, the model is loaded and it is a supported version."""
        response = self._request("GET", "/health")
        if response.status_code != 200:
            raise errors.ml_unavailable("The diabetes assessment service is unavailable right now. Please try again later.")
        try:
            body = response.json()
        except ValueError:
            raise errors.ml_unavailable("The diabetes assessment service is unavailable right now. Please try again later.")
        if body.get("status") != "ok" or body.get("model_loaded") is not True:
            raise errors.ml_unavailable("The diabetes assessment model is not ready yet. Please try again shortly.")
        if version_major(body.get("model_version")) != SUPPORTED_MAJOR:
            log.error("diabetes risk API version %r is not supported (expected %d.x)", body.get("model_version"), SUPPORTED_MAJOR)
            raise errors.ApiError(502, "model_version_unsupported", "The diabetes assessment service was updated and SUSTHITI needs an update to use it.")
        return body

    def predict(self, data: dict[str, Any]) -> RiskPrediction:
        response = self._request("POST", "/predict", json={"data": data})
        if response.status_code == 422:
            # Field-level constraint messages from the API (no patient values in them).
            detail = _safe_detail(response)
            log.warning("diabetes risk API rejected inputs: %s", detail)
            raise errors.unprocessable("Some health information could not be used by the risk model. Please review your health profile.", {"model_errors": detail})
        if response.status_code in (502, 503, 504):
            raise errors.ml_unavailable("The diabetes assessment service is unavailable right now. Please try again later.")
        if response.status_code != 200:
            raise errors.ml_failed()
        try:
            return parse_response(response.json(), sent=data)
        except (ValueError, KeyError, TypeError) as exc:
            log.error("diabetes risk API returned an invalid response: %s", exc)
            raise errors.ml_failed()


def parse_response(body: Any, sent: dict[str, Any]) -> RiskPrediction:
    """Validates an API v4 /predict reply field by field. Raises ValueError if anything is off."""
    if not isinstance(body, dict) or body.get("success") is not True:
        raise ValueError("success is not true")
    risk = body["future_diabetes_risk_percent"]
    if isinstance(risk, bool) or not isinstance(risk, (int, float)) or not 0 <= risk <= 100:
        raise ValueError("future_diabetes_risk_percent out of range")
    category = body["risk_category"]
    if category not in CATEGORIES:
        raise ValueError("unknown risk_category")
    prediction = body["prediction"]
    if prediction not in (0, 1) or isinstance(prediction, bool):
        raise ValueError("prediction must be 0 or 1")
    basis = body["prediction_basis"]
    if basis not in BASES:
        raise ValueError("unknown prediction_basis")
    available = body["report_available"]
    present = body.get("report_fields_present") or []
    if not isinstance(available, bool) or not isinstance(present, list) or not set(present) <= set(REPORT_FIELDS):
        raise ValueError("invalid report fields")
    # The API decides report availability from the report fields; it must agree with what was sent.
    expected = [f for f in REPORT_FIELDS if sent.get(f) is not None]
    if sorted(present) != sorted(expected) or available != bool(expected):
        raise ValueError("report_fields_present does not match the request")
    if (basis == BASES[1]) != available:
        raise ValueError("prediction_basis does not match report_available")
    version = str(body["model_version"])
    if version_major(version) != SUPPORTED_MAJOR:
        raise ValueError(f"unsupported model_version {version!r}")
    bmi = body.get("bmi")
    if bmi is not None and (isinstance(bmi, bool) or not isinstance(bmi, (int, float))):
        raise ValueError("bmi must be a number")
    thresholds = body.get("risk_thresholds") or {}
    if not isinstance(thresholds, dict):
        raise ValueError("risk_thresholds must be an object")
    return RiskPrediction(
        success=True, risk_percent=float(risk), risk_category=category, risk_thresholds={str(k): str(v) for k, v in thresholds.items()},
        prediction=int(prediction), prediction_label=_text(body.get("prediction_label")) or ("Higher-risk pattern" if prediction else "Lower-risk pattern"),
        prediction_threshold=_text(body.get("prediction_threshold")), prediction_basis=basis, report_available=available,
        report_fields_present=[f for f in REPORT_FIELDS if f in present], bmi=None if bmi is None else float(bmi),
        model_version=version, warning=_text(body.get("warning")),
    )


def _text(value: Any) -> str | None:
    return value.strip()[:1000] if isinstance(value, str) and value.strip() else None


def _safe_detail(response: httpx.Response) -> list[str]:
    try:
        detail = response.json().get("detail")
    except ValueError:
        return []
    items = detail if isinstance(detail, list) else [detail]
    return [str(d)[:200] for d in items if d][:10]


_client: DiabetesRiskApiClient | None = None


def get_risk_client() -> DiabetesRiskApiClient:
    global _client
    if _client is None:
        _client = DiabetesRiskApiV4Client()
    return _client


def set_risk_client(client: DiabetesRiskApiClient | None) -> None:
    """Tests replace the client with one using a mock transport."""
    global _client
    _client = client
