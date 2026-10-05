from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Backend configuration. Every secret comes from the environment or a local .env file."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    susthiti_env: str = "development"
    database_url: str = "sqlite:///./susthiti.db"
    jwt_secret: str = "dev-only-insecure-secret-change-me"
    jwt_algorithm: str = "HS256"
    session_hours: int = 168

    storage_dir: str = "./storage"
    max_upload_mb: int = 20

    cors_origins: str = "*"

    ml_service_url: str = "http://127.0.0.1:8001"
    ml_service_timeout_seconds: float = 15

    heart_model_service_url: str = "http://127.0.0.1:8002"
    heart_model_service_timeout_seconds: float = 15

    # The AI gateway for all summary/interpretation features (report, patient, lifestyle):
    # a trusted server-side call to OpenRouter. The key never leaves the backend.
    openrouter_api_key: str = ""
    openrouter_model: str = "google/gemma-4-31b-it:free"
    openrouter_base_url: str = "https://openrouter.ai/api/v1"
    ai_timeout_seconds: float = 90
    # Read HbA1c / glucose from scanned reports and photos with the AI service after upload.
    ai_read_report_values: bool = True

    # Path to a Firebase service-account JSON key. Push notifications are a no-op (logged once)
    # until this is set -- the app never holds this key; only the backend sends pushes.
    fcm_service_account_json: str = ""

    enable_demo_wearable: bool = True
    # Throttles sign-in, registration and password reset per client, and AI/risk-prediction
    # calls per signed-in user (see services/rate_limit.py). Required in production.
    auth_rate_limit_enabled: bool = True
    dev_expose_reset_token: bool = False
    reminders_enabled: bool = True
    reminder_interval_minutes: int = 60
    # Where patients are: "today" for birthdays and appointment reminders.
    local_timezone: str = "Asia/Kolkata"

    # Resend email delivery (https://resend.com): server-side only, never shipped to Flutter.
    # Leave empty to log a safe warning without sending real email.
    resend_api_key: str = ""
    resend_from_email: str = ""
    resend_from_name: str = "SUSTHITI"
    resend_timeout_seconds: float = 10.0
    password_reset_expiry_minutes: int = 30

    @property
    def is_production(self) -> bool:
        return self.susthiti_env.lower() == "production"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def ai_configured(self) -> bool:
        return bool(self.openrouter_api_key)

    @property
    def fcm_configured(self) -> bool:
        return bool(self.fcm_service_account_json)

    @property
    def resend_configured(self) -> bool:
        return bool(self.resend_api_key and self.resend_from_email)


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    if settings.is_production:
        if settings.jwt_secret.startswith("dev-only") or len(settings.jwt_secret) < 32:
            raise RuntimeError("JWT_SECRET must be set to a strong value in production.")
        if settings.dev_expose_reset_token:
            raise RuntimeError("DEV_EXPOSE_RESET_TOKEN must be false in production.")
        if settings.enable_demo_wearable:
            raise RuntimeError("ENABLE_DEMO_WEARABLE must be false in production: real patients must never be offered demo data.")
        if not settings.auth_rate_limit_enabled:
            raise RuntimeError("AUTH_RATE_LIMIT_ENABLED must be true in production.")
    return settings
