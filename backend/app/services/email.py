"""Email delivery service using Resend HTTP API.

Strictly server-side: API keys and credentials never leave the backend and are
never logged. Reset tokens are never logged. Failures are handled safely so that
email provider downtime or network glitches never crash the API.
"""

import html as html_lib
import logging
from dataclasses import dataclass

import httpx

from ..config import get_settings

log = logging.getLogger("susthiti.email")


@dataclass(frozen=True)
class EmailDeliveryResult:
    """Result of an email delivery attempt."""

    success: bool
    message_id: str | None = None
    error: str | None = None


class EmailService:
    """Transactional email service powered by Resend (https://api.resend.com/emails)."""

    RESEND_API_URL = "https://api.resend.com/emails"

    def __init__(
        self,
        api_key: str | None = None,
        from_email: str | None = None,
        from_name: str | None = None,
        timeout: float | None = None,
        transport: httpx.BaseTransport | None = None,
    ):
        settings = get_settings()
        self.api_key = (api_key if api_key is not None else settings.resend_api_key).strip()
        self.from_email = (from_email if from_email is not None else settings.resend_from_email).strip()
        self.from_name = (from_name if from_name is not None else settings.resend_from_name).strip()
        self.timeout = timeout if timeout is not None else settings.resend_timeout_seconds
        self.transport = transport

    @property
    def configured(self) -> bool:
        """Returns True only when both API key and sender email are configured."""
        return bool(self.api_key and self.from_email)

    def _format_from(self) -> str:
        """Formats the RFC 5322 From address safely."""
        if "<" in self.from_email and ">" in self.from_email:
            return self.from_email
        if self.from_name:
            return f"{self.from_name} <{self.from_email}>"
        return self.from_email

    def send_email(
        self,
        to: str,
        subject: str,
        text: str,
        html: str | None = None,
    ) -> EmailDeliveryResult:
        """Sends an email via Resend HTTP API with bounded timeout and safe error handling."""
        if not self.configured:
            log.warning("Email delivery skipped: Resend is not configured (RESEND_API_KEY or RESEND_FROM_EMAIL is missing).")
            return EmailDeliveryResult(success=False, error="provider_not_configured")

        payload = {
            "from": self._format_from(),
            "to": [to.strip().lower()],
            "subject": subject,
            "text": text,
        }
        if html:
            payload["html"] = html

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        try:
            with httpx.Client(timeout=self.timeout, transport=self.transport) as client:
                response = client.post(self.RESEND_API_URL, json=payload, headers=headers)

            if response.status_code in (200, 201):
                try:
                    data = response.json()
                    message_id = data.get("id")
                except Exception:
                    message_id = None
                log.info("Email sent successfully via Resend (status=%s, id=%s)", response.status_code, message_id)
                return EmailDeliveryResult(success=True, message_id=message_id)

            log.error("Resend API error: HTTP %s", response.status_code)
            return EmailDeliveryResult(success=False, error=f"provider_error_{response.status_code}")

        except httpx.TimeoutException:
            log.error("Resend API request timed out after %.1fs", self.timeout)
            return EmailDeliveryResult(success=False, error="timeout")
        except httpx.RequestError as exc:
            log.error("Resend API network request failed: %s", type(exc).__name__)
            return EmailDeliveryResult(success=False, error="network_error")
        except Exception as exc:
            log.error("Unexpected error delivering email: %s", type(exc).__name__)
            return EmailDeliveryResult(success=False, error="unexpected_error")

    def send_password_reset_email(
        self,
        to_email: str,
        user_name: str | None,
        reset_token: str,
        expiry_minutes: int = 30,
    ) -> EmailDeliveryResult:
        """Sends a professional SUSTHITI password reset email with the user's reset code."""
        name = (user_name or "").strip() or "there"
        subject = "SUSTHITI Password Reset"

        text_body = (
            f"Hello {name},\n\n"
            "We received a request to reset your SUSTHITI account password.\n\n"
            "Your password reset code is:\n\n"
            f"{reset_token}\n\n"
            f"This code expires after {expiry_minutes} minutes.\n\n"
            "If you did not request this password reset, you can safely ignore this email.\n\n"
            "For security, do not share this code with anyone.\n\n"
            "Regards,\n"
            "SUSTHITI Team\n"
        )

        safe_name = html_lib.escape(name)
        safe_token = html_lib.escape(reset_token)
        html_body = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>{subject}</title></head>
<body style="margin: 0; padding: 24px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; color: #1e293b; line-height: 1.6;">
  <div style="max-width: 560px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 32px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);">
    <div style="border-bottom: 2px solid #0d9488; padding-bottom: 16px; margin-bottom: 24px;">
      <h1 style="color: #0d9488; margin: 0; font-size: 24px; font-weight: 700; letter-spacing: -0.5px;">SUSTHITI</h1>
    </div>
    <p style="font-size: 16px; margin-top: 0;">Hello {safe_name},</p>
    <p style="font-size: 15px; color: #334155;">We received a request to reset your SUSTHITI account password.</p>
    <p style="font-size: 15px; color: #334155; margin-bottom: 8px;">Your password reset code is:</p>
    <div style="background-color: #f1f5f9; border: 1px solid #cbd5e1; border-radius: 8px; padding: 16px; text-align: center; margin: 16px 0;">
      <span style="font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 20px; font-weight: 700; color: #0f172a; letter-spacing: 2px; word-break: break-all;">{safe_token}</span>
    </div>
    <p style="font-size: 14px; color: #64748b;">This code expires after {expiry_minutes} minutes.</p>
    <p style="font-size: 14px; color: #64748b;">If you did not request this password reset, you can safely ignore this email.</p>
    <p style="font-size: 14px; color: #dc2626; font-weight: 500;">For security, do not share this code with anyone.</p>
    <div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid #e2e8f0; font-size: 14px; color: #475569;">
      Regards,<br>
      <strong>SUSTHITI Team</strong>
    </div>
  </div>
</body>
</html>"""

        return self.send_email(
            to=to_email,
            subject=subject,
            text=text_body,
            html=html_body,
        )


_email_service: EmailService | None = None


def get_email_service() -> EmailService:
    """Returns the configured EmailService singleton."""
    global _email_service
    if _email_service is None:
        _email_service = EmailService()
    return _email_service


def set_email_service(service: EmailService | None) -> None:
    """Overrides or resets the EmailService singleton (primarily for testing)."""
    global _email_service
    _email_service = service
