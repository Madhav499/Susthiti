from fastapi import HTTPException


class ApiError(HTTPException):
    """HTTP error with a stable machine-readable code the Flutter app maps to a Failure type."""

    def __init__(self, status_code: int, code: str, message: str, details: dict | None = None):
        super().__init__(status_code=status_code, detail={"code": code, "message": message, "details": details or {}})


def too_many_attempts(retry_after_seconds: int) -> ApiError:
    error = ApiError(429, "rate_limited", "Too many attempts. Please wait a few minutes and try again.", {"retry_after_seconds": retry_after_seconds})
    error.headers = {"Retry-After": str(retry_after_seconds)}
    return error


def bad_request(message: str, code: str = "validation_error", details: dict | None = None) -> ApiError:
    return ApiError(400, code, message, details)


def unauthorized(message: str = "Please sign in again.") -> ApiError:
    return ApiError(401, "authentication_error", message)


def forbidden(message: str = "You don't have permission to access this information.") -> ApiError:
    return ApiError(403, "authorization_error", message)


def not_found(what: str = "Record") -> ApiError:
    return ApiError(404, "not_found", f"{what} not found.")


def conflict(message: str) -> ApiError:
    return ApiError(409, "conflict", message)


def unprocessable(message: str, details: dict | None = None) -> ApiError:
    return ApiError(422, "validation_error", message, details)


def ml_unavailable(message: str = "The assessment service is temporarily unavailable. Please try again later.") -> ApiError:
    return ApiError(503, "model_service_unavailable", message)


def ml_timeout() -> ApiError:
    return ApiError(504, "model_service_timeout", "The assessment took too long to complete. Please try again.")


def ml_failed() -> ApiError:
    """The service answered but could not produce a result (its own error or a malformed reply)."""
    return ApiError(502, "model_inference_failed", "We couldn't process the assessment right now. Your answers have not been treated as a diagnosis.")


def ai_unavailable(message: str = "AI summary unavailable right now.", code: str = "ai_service_unavailable") -> ApiError:
    return ApiError(503, code, message)
