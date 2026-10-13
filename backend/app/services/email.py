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
from .i18n import password_reset_email_text

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
        locale: str = "en",
    ) -> EmailDeliveryResult:
        """Sends a professional SUSTHITI password reset email with the user's reset code, in
        the recipient's OWN saved preferred_locale -- this runs before the user is
        authenticated for this request, so their account's saved preference (not a
        request-time choice) is the only language signal available, and the only one that
        makes sense: it's still addressed to them."""
        name = (user_name or "").strip() or "there"
        text = password_reset_email_text(locale)
        subject = text["subject"]

        text_body = (
            f"{text['greeting'].format(name=name)}\n\n"
            f"{text['intro']}\n\n"
            f"{text['code_label']}\n\n"
            f"{reset_token}\n\n"
            f"{text['expiry'].format(minutes=expiry_minutes)}\n\n"
            f"{text['ignore']}\n\n"
            f"{text['warning']}\n\n"
            f"{text['regards']}\n"
            f"{text['team']}\n"
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
    <p style="font-size: 16px; margin-top: 0;">{text['greeting'].format(name=safe_name)}</p>
    <p style="font-size: 15px; color: #334155;">{text['intro']}</p>
    <p style="font-size: 15px; color: #334155; margin-bottom: 8px;">{text['code_label']}</p>
    <div style="background-color: #f0fdf4; border: 1.5px solid #0d9488; border-radius: 10px; padding: 20px; text-align: center; margin: 24px 0;">
      <div style="font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace; font-size: 32px; font-weight: 700; color: #0f172a; letter-spacing: 6px; user-select: all;">{safe_token}</div>
    </div>
    <p style="font-size: 14px; color: #64748b;">{text['expiry'].format(minutes=expiry_minutes)}</p>
    <p style="font-size: 14px; color: #64748b;">{text['ignore']}</p>
    <p style="font-size: 14px; color: #dc2626; font-weight: 500;">{text['warning']}</p>
    <div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid #e2e8f0; font-size: 14px; color: #475569;">
      {text['regards']}<br>
      <strong>{text['team']}</strong>
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
