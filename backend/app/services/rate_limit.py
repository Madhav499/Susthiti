"""Rate limiting, in memory, for two kinds of endpoint:

- Public sign-in endpoints (`limit`), so passwords can't be guessed at speed once the server is
  on the internet. Counted per client address.
- Authenticated endpoints that call a metered external service -- AI summaries (OpenRouter) and
  risk predictions (the diabetes/heart ML services) -- via `limit_by_user`, so one account can't
  run either up for free in a loop. Counted per signed-in user id, never per client-supplied id.

Both share one in-memory counter, correct for the single backend process SUSTHITI runs today (the
reminder loop also assumes one process). If this backend is ever run as more than one instance,
each instance keeps its own counters and the effective limit multiplies by instance count -- that
is a real limitation of this approach, not something routing around it would fix without adding
shared infrastructure (e.g. Redis) this project doesn't otherwise need; see DEPLOY.md before
scaling horizontally.

Behind the reverse proxy the client address comes from X-Forwarded-For, so uvicorn must run
with --proxy-headers (the Docker image does); otherwise every visitor would share one counter.
"""

import threading
import time
from collections import defaultdict, deque

from fastapi import Depends, Request

from .. import errors
from ..config import get_settings
from ..deps import CurrentUser, get_current_user


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


def limit_by_user(bucket: str, attempts: int, per_seconds: int):
    """FastAPI dependency: at most `attempts` requests per SIGNED-IN USER in `per_seconds`, for
    an endpoint that already requires authentication and calls a metered external service.

    Keyed by `current.id` -- the user id FastAPI resolves from the verified JWT via
    `get_current_user`, the same dependency every other authorization check in this codebase
    already goes through -- never by a client-supplied `patient_id`/`doctor_id`, and never by IP
    alone (IP-only would over-limit many users sharing one network and under-limit one user who
    simply switches networks). `get_current_user` is cached per request by FastAPI, so this
    costs nothing extra beyond the authorization check the route already performs."""

    def dependency(current: CurrentUser = Depends(get_current_user)) -> None:
        if not get_settings().auth_rate_limit_enabled:
            return
        retry_after = limiter.hit(f"{bucket}:user:{current.id}", attempts, per_seconds)
        if retry_after is not None:
            raise errors.too_many_attempts(int(retry_after) + 1)

    return dependency
