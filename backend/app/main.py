import asyncio
import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .config import get_settings
from .db import SessionLocal, init_db
from .routers import access, admin, admin_profiles, ai, auth, care, diabetes, diabetes_risk, follow_ups, health_data, notifications, patients, reports, surgeries, tracking
from .services.reminders import reminder_loop

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger("susthiti")


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    init_db()
    task = None
    if settings.reminders_enabled:
        task = asyncio.create_task(reminder_loop(SessionLocal, settings.reminder_interval_minutes))
    yield
    if task:
        task.cancel()


settings = get_settings()
# The interactive API docs are for development; a public server doesn't advertise its API.
_docs = {} if not settings.is_production else {"docs_url": None, "redoc_url": None, "openapi_url": None}
app = FastAPI(title="SUSTHITI API", version="1.0.0", lifespan=lifespan, **_docs)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list or ["*"],
    # Local development only: `flutter run -d chrome` (and Android Studio) serve the web app on a
    # new random localhost port each run. Production accepts only the CORS_ORIGINS list.
    allow_origin_regex=None if settings.is_production else r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["Authorization", "Content-Type"],
    expose_headers=["Content-Disposition"],
)


@app.middleware("http")
async def request_log(request: Request, call_next):
    """Logs method, route template, status and timing only. Never bodies, ids or tokens."""
    start = time.perf_counter()
    response = await call_next(request)
    route = request.scope.get("route")
    path = getattr(route, "path", "unmatched")
    log.info("%s %s -> %s (%.0f ms)", request.method, path, response.status_code, (time.perf_counter() - start) * 1000)
    return response


@app.exception_handler(RequestValidationError)
async def validation_handler(request: Request, exc: RequestValidationError):
    first = exc.errors()[0] if exc.errors() else {}
    field = ".".join(str(p) for p in first.get("loc", [])[1:]) or None
    message = str(first.get("msg", "Invalid input.")).removeprefix("Value error, ")
    return JSONResponse(status_code=422, content={"detail": {"code": "validation_error", "message": message, "details": {"field": field}}})


@app.exception_handler(Exception)
async def unhandled(request: Request, exc: Exception):
    log.exception("unhandled error type=%s", type(exc).__name__)
    return JSONResponse(status_code=500, content={"detail": {"code": "server_error", "message": "Something went wrong. Please try again.", "details": {}}})


@app.get("/health")
def health():
    """Liveness plus whether the diabetes model service is reachable, so a missing model service is
    visible here instead of only as a failed assessment."""
    import httpx

    from .services.diabetes_risk.client import version_major
    from .services.diabetes_risk.features import SUPPORTED_MAJOR

    settings = get_settings()
    model_version = None
    try:
        ml = httpx.get(f"{settings.ml_service_url.rstrip('/')}/health", timeout=2)
        body = ml.json() if ml.status_code == 200 else {}
        model_version = body.get("model_version")
        if body.get("status") == "ok" and body.get("model_loaded") is True:
            model_service = "ok" if version_major(model_version) == SUPPORTED_MAJOR else "unsupported_version"
        else:
            model_service = "not_ready"
    except (httpx.HTTPError, ValueError):
        model_service = "unreachable"
    return {"status": "ok", "ai_configured": settings.ai_configured, "model_service": model_service, "model_version": model_version}


for module in (auth, patients, reports, diabetes, diabetes_risk, health_data, tracking, care, access, follow_ups, surgeries, notifications, admin, admin_profiles, ai):
    app.include_router(module.router, prefix="/api/v1")
