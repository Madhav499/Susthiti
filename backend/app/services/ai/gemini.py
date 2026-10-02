"""Minimal Google AI Studio (Gemini) client. The API key lives only in backend config."""

import base64
import json
import logging
import time
from dataclasses import dataclass, field

import httpx
from pydantic import BaseModel, ValidationError

from ... import errors
from ...config import get_settings

log = logging.getLogger("susthiti.ai")

# Transient upstream failures get a bounded retry with exponential backoff, honoring
# Retry-After when Gemini sends one. Never unbounded: the whole attempt (all retries plus
# sleeps) stays within AI_TIMEOUT_SECONDS, and a non-retryable status fails immediately.
_RETRYABLE_STATUSES = {429, 500, 502, 503, 504}
_MAX_ATTEMPTS = 3
_BASE_BACKOFF_SECONDS = 1.0


def _backoff_seconds(attempt: int) -> float:
    return _BASE_BACKOFF_SECONDS * (2 ** (attempt - 1))


def _retry_after_seconds(response: httpx.Response) -> float | None:
    value = response.headers.get("retry-after")
    if value is None:
        return None
    try:
        return max(0.0, float(value))
    except ValueError:
        return None

DISCLAIMER = (
    "AI-generated informational summary. This does not replace professional medical judgment."
)


@dataclass
class Part:
    text: str | None = None
    data: bytes | None = None
    mime_type: str | None = None

    def to_json(self) -> dict:
        if self.data is not None:
            return {"inlineData": {"mimeType": self.mime_type, "data": base64.b64encode(self.data).decode()}}
        return {"text": self.text or ""}


@dataclass
class AIResult:
    content: dict
    provider: str = "google-ai-studio"
    model: str = ""
    prompt_version: str = ""
    extra: dict = field(default_factory=dict)


class GeminiClient:
    def __init__(self, api_key: str | None = None, model: str | None = None, transport: httpx.BaseTransport | None = None):
        settings = get_settings()
        self.api_key = settings.gemini_api_key if api_key is None else api_key
        self.model = model or settings.gemini_model
        self.base_url = settings.gemini_base_url.rstrip("/")
        self.timeout = settings.ai_timeout_seconds
        self.transport = transport

    @property
    def configured(self) -> bool:
        return bool(self.api_key)

    def generate_json(self, system_instruction: str, parts: list[Part], schema: type[BaseModel], prompt_version: str = "") -> AIResult:
        if not self.configured:
            raise errors.ai_unavailable(
                "AI features are not configured on the server yet.", code="ai_not_configured"
            )
        body = {
            "systemInstruction": {"parts": [{"text": system_instruction}]},
            "contents": [{"role": "user", "parts": [p.to_json() for p in parts]}],
            "generationConfig": {"responseMimeType": "application/json", "temperature": 0.2},
        }
        url = f"{self.base_url}/models/{self.model}:generateContent"
        deadline = time.monotonic() + self.timeout
        last_error: errors.ApiError = errors.ai_unavailable()
        for attempt in range(1, _MAX_ATTEMPTS + 1):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            try:
                with httpx.Client(timeout=remaining, transport=self.transport) as client:
                    response = client.post(url, json=body, headers={"x-goog-api-key": self.api_key})
            except httpx.TimeoutException:
                log.warning("ai request timeout model=%s attempt=%s", self.model, attempt)
                last_error = errors.ai_unavailable("The AI service took too long to respond.", code="ai_timeout")
                break  # the remaining budget was already spent waiting; retrying can't help
            except httpx.HTTPError as exc:
                log.warning("ai request network error type=%s attempt=%s", type(exc).__name__, attempt)
                last_error = errors.ai_unavailable()
                remaining = deadline - time.monotonic()
                if attempt == _MAX_ATTEMPTS or remaining <= 0:
                    break
                time.sleep(min(_backoff_seconds(attempt), remaining))
                continue
            log.info("ai request model=%s status=%s attempt=%s", self.model, response.status_code, attempt)
            if response.status_code == 200:
                return AIResult(content=parse_json_output(response.json(), schema), model=self.model, prompt_version=prompt_version)
            last_error = errors.ai_unavailable()
            if response.status_code not in _RETRYABLE_STATUSES:
                break
            remaining = deadline - time.monotonic()
            if attempt == _MAX_ATTEMPTS or remaining <= 0:
                break
            wait = _retry_after_seconds(response)
            time.sleep(min(wait if wait is not None else _backoff_seconds(attempt), remaining))
        raise last_error


def parse_json_output(payload: dict, schema: type[BaseModel]) -> dict:
    """Extracts and validates the model's JSON text. Raises a retryable error when it can't."""
    try:
        candidate = payload["candidates"][0]
        text = "".join(p.get("text", "") for p in candidate["content"]["parts"])
        text = text.strip()
        if text.startswith("```"):
            text = text.strip("`")
            text = text[text.find("{"):]
        data = json.loads(text)
        return schema.model_validate(data).model_dump()
    except (KeyError, IndexError, TypeError, ValueError, ValidationError):
        raise errors.ApiError(
            502, "ai_invalid_response", "We couldn't read the AI response. Please try again."
        )
