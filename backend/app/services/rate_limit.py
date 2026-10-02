"""Limits on the public sign-in endpoints, so passwords can't be guessed at speed once the server
is on the internet. Counted per client address in memory, which is correct for the single
backend process SUSTHITI runs (the reminder loop also assumes one process).

Behind the reverse proxy the client address comes from X-Forwarded-For, so uvicorn must run
with --proxy-headers (the Docker image does); otherwise every visitor would share one counter.
"""

import threading
import time
from collections import defaultdict, deque

from fastapi import Request

from .. import errors
from ..config import get_settings


class RateLimiter:
    def __init__(self) -> None:
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def hit(self, key: str, limit: int, window_seconds: float, now: float | None = None) -> float | None:
        """Records an attempt. Returns None when allowed, else seconds until the next one is."""
        now = time.monotonic() if now is None else now
        with self._lock:
            attempts = self._hits[key]
            while attempts and attempts[0] <= now - window_seconds:
                attempts.popleft()
            if len(attempts) >= limit:
                return attempts[0] + window_seconds - now
            attempts.append(now)
            if len(self._hits) > 50_000:  # never grow without bound
                self._prune(now, window_seconds)
            return None

    def _prune(self, now: float, window_seconds: float) -> None:
        for key in [k for k, v in self._hits.items() if not v or v[-1] <= now - window_seconds]:
            del self._hits[key]

    def reset(self) -> None:
        with self._lock:
            self._hits.clear()


limiter = RateLimiter()


def limit(bucket: str, attempts: int, per_seconds: int):
    """FastAPI dependency: at most `attempts` requests per client in `per_seconds`."""

    def dependency(request: Request) -> None:
        if not get_settings().auth_rate_limit_enabled:
            return
        client = request.client.host if request.client else "unknown"
        retry_after = limiter.hit(f"{bucket}:{client}", attempts, per_seconds)
        if retry_after is not None:
            raise errors.too_many_attempts(int(retry_after) + 1)

    return dependency
