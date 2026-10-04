"""Client for the SUSTHITI Heart Disease Risk API (model susthiti-heart-v3), a private service
only this backend calls (HEART_MODEL_SERVICE_URL). It never produces or adjusts a prediction
itself: it sends the model features, then checks the reply is complete and consistent before
anything is stored. Mirrors services/diabetes_risk/client.py's shape exactly.

The supplied model is trained on synthetic data (see heart_risk_api/README_API.md). Its result
is a screening signal, not a diagnosis -- callers must not relabel it as one.
"""

import logging
from dataclasses import dataclass
from typing import Any, Protocol

import httpx

from ... import errors
from ...config import get_settings
from .features import FEATURES, MODEL_VERSION

log = logging.getLogger("susthiti.heart_risk")

RISK_LEVELS = ("low", "moderate", "high")


@dataclass(frozen=True)
class HeartPrediction:
    prediction: int
    prediction_label: str
    probability_percent: float
    risk_level: str
    decision_threshold: float
    model_version: str
    warnings: list[str]


class HeartRiskApiClient(Protocol):
    def health(self) -> dict: ...

    def predict(self, data: dict[str, Any]) -> HeartPrediction: ...


class HeartRiskApiV3Client:
    def __init__(self, base_url: str | None = None, transport: httpx.BaseTransport | None = None):
        settings = get_settings()
        self.base_url = (base_url or settings.heart_model_service_url).rstrip("/")
        self.timeout = settings.heart_model_service_timeout_seconds
        self.transport = transport

    def _request(self, method: str, path: str, **kwargs) -> httpx.Response:
        try:
            with httpx.Client(timeout=self.timeout, transport=self.transport) as client:
                return client.request(method, f"{self.base_url}{path}", **kwargs)
        except httpx.TimeoutException:
            raise errors.ml_timeout()
        except httpx.HTTPError:  # refused, DNS, network
            raise errors.ml_unavailable("The heart risk screening service is unavailable right now. Please try again later.")

    def health(self) -> dict:
        """Confirms the service is up and serving the expected model version."""
        response = self._request("GET", "/health")
        if response.status_code != 200:
            raise errors.ml_unavailable("The heart risk screening service is unavailable right now. Please try again later.")
        try:
            body = response.json()
        except ValueError:
            raise errors.ml_unavailable("The heart risk screening service is unavailable right now. Please try again later.")
        if body.get("status") != "ok":
            raise errors.ml_unavailable("The heart risk screening model is not ready yet. Please try again shortly.")
        if body.get("model_version") != MODEL_VERSION:
            log.error("heart risk API model_version %r is not the supported %r", body.get("model_version"), MODEL_VERSION)
            raise errors.ApiError(502, "model_version_unsupported", "The heart risk screening service was updated and SUSTHITI needs an update to use it.")
        return body

    def model_info(self) -> dict:
        """Used only to cross-check FEATURES against the live service; never trusted blindly."""
        response = self._request("GET", "/model-info")
        if response.status_code != 200:
            raise errors.ml_unavailable("The heart risk screening service is unavailable right now. Please try again later.")
        try:
            return response.json()
        except ValueError:
            raise errors.ml_unavailable("The heart risk screening service is unavailable right now. Please try again later.")

    def predict(self, data: dict[str, Any]) -> HeartPrediction:
        response = self._request("POST", "/predict", json={"data": data})
        if response.status_code == 422:
            detail = _safe_detail(response)
            log.warning("heart risk API rejected inputs: %s", detail)
            raise errors.unprocessable("Some health information could not be used by the heart risk model. Please review the assessment form.", {"model_errors": detail})
        if response.status_code in (502, 503, 504):
            raise errors.ml_unavailable("The heart risk screening service is unavailable right now. Please try again later.")
        if response.status_code != 200:
            raise errors.ml_failed()
        try:
            return parse_response(response.json())
        except (ValueError, KeyError, TypeError) as exc:
            log.error("heart risk API returned an invalid response: %s", exc)
            raise errors.ml_failed()


def parse_response(body: Any) -> HeartPrediction:
    """Validates a /predict reply field by field. Raises ValueError if anything is off."""
    if not isinstance(body, dict):
        raise ValueError("response is not an object")
    prediction = body["prediction"]
    if prediction not in (0, 1) or isinstance(prediction, bool):
        raise ValueError("prediction must be 0 or 1")
    probability_percent = body["probability_percent"]
    if isinstance(probability_percent, bool) or not isinstance(probability_percent, (int, float)) or not 0 <= probability_percent <= 100:
        raise ValueError("probability_percent out of range")
    risk_level = body["risk_level"]
    if risk_level not in RISK_LEVELS:
        raise ValueError("unknown risk_level")
    threshold = body["decision_threshold"]
    if isinstance(threshold, bool) or not isinstance(threshold, (int, float)):
        raise ValueError("decision_threshold must be a number")
    version = str(body["model_version"])
    if version != MODEL_VERSION:
        raise ValueError(f"unsupported model_version {version!r}")
    warnings = body.get("warnings") or []
    if not isinstance(warnings, list):
        raise ValueError("warnings must be a list")
    return HeartPrediction(
        prediction=int(prediction), prediction_label=_text(body.get("prediction_label")) or ("Elevated risk signal" if prediction else "No elevated risk signal"),
        probability_percent=float(probability_percent), risk_level=risk_level, decision_threshold=float(threshold),
        model_version=version, warnings=[str(w)[:300] for w in warnings][:10],
    )


def _text(value: Any) -> str | None:
    return value.strip()[:1000] if isinstance(value, str) and value.strip() else None


def _safe_detail(response: httpx.Response) -> list[str]:
    try:
        detail = response.json().get("detail")
    except ValueError:
        return []
    if isinstance(detail, dict):
        detail = detail.get("errors", detail)
    items = detail if isinstance(detail, list) else [detail]
    return [str(d)[:200] for d in items if d][:10]


def check_features(client: "HeartRiskApiV3Client") -> None:
    """Cross-checks the hand-written FEATURES list in features.py against the live service's
    /model-info, so a transcription drift is caught loudly instead of silently sending/omitting
    the wrong fields. Runs once, only against the real lazily-constructed default client --
    never against a test double injected via set_risk_client()."""
    info = client.model_info()
    live = set(info.get("features") or [])
    if live and live != set(FEATURES):
        log.error("heart risk API /model-info features do not match FEATURES: missing=%s extra=%s", set(FEATURES) - live, live - set(FEATURES))
        raise errors.ApiError(502, "model_version_unsupported", "The heart risk screening service was updated and SUSTHITI needs an update to use it.")


_client: HeartRiskApiClient | None = None


def get_risk_client() -> HeartRiskApiClient:
    global _client
    if _client is None:
        default = HeartRiskApiV3Client()
        check_features(default)
        _client = default
    return _client


def set_risk_client(client: HeartRiskApiClient | None) -> None:
    """Tests replace the client with one using a mock transport (skips the live features check)."""
    global _client
    _client = client
