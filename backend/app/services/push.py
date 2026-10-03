"""Push delivery via Firebase Cloud Messaging. Strictly supplementary to the in-app
`Notification` row `notify()` already creates: a push failure, or FCM not being configured at
all, never blocks or undoes that row. Quiet (one warning, not a crash) until a service-account
key is set, so this is safe to ship and call before any Firebase project exists -- exactly the
state this backend is in until someone creates one and sets FCM_SERVICE_ACCOUNT_JSON.
"""

import logging
from functools import lru_cache

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import get_settings
from ..models import DeviceToken

log = logging.getLogger("susthiti.push")
_warned_unconfigured = False

# Which Android channel (and delivery priority) each notification `type` arrives on. Mirrors
# the channels PushNotificationService creates on the device -- the ids must match exactly.
# Not every type is actionable or time-sensitive, so not everything is "high": a channel the
# patient can mute, and a priority that doesn't interrupt for a routine update, are part of
# the notification actually being respected rather than ignored or disabled outright.
_IMPORTANT = {"access_request", "surgery_reminder", "follow_up_reminder"}
_APPOINTMENTS = {
    "appointment_recommendation", "follow_up_scheduled", "follow_up_rescheduled", "follow_up_cancelled",
    "surgery_scheduled", "surgery_rescheduled", "surgery_cancelled", "access_approved",
}
_HEALTH = {"new_report", "report_summary_ready", "new_prescription", "visit_recorded", "access_rejected", "access_revoked"}
# Everything else (food_reminder, lifestyle_reminder, birthday, and any future type) -> general.


def _channel_for(notification_type: str | None) -> tuple[str, str]:
    """(android_channel_id, android_priority) for a notification type. An unmapped or missing
    type is deliberately treated as routine rather than important -- new notification types
    should have to opt in to interrupting the user, not default to it."""
    if notification_type in _IMPORTANT:
        return "susthiti_important", "high"
    if notification_type in _APPOINTMENTS:
        return "susthiti_appointments", "high"
    if notification_type in _HEALTH:
        return "susthiti_health", "normal"
    return "susthiti_general", "normal"


@lru_cache(maxsize=1)
def _app():
    """None when FCM isn't configured or the key is invalid. Cached: the key is read once."""
    settings = get_settings()
    if not settings.fcm_configured:
        return None
    import firebase_admin
    from firebase_admin import credentials

    try:
        return firebase_admin.initialize_app(credentials.Certificate(settings.fcm_service_account_json))
    except Exception:
        log.exception("could not initialize the Firebase Admin SDK; check FCM_SERVICE_ACCOUNT_JSON")
        return None


def send_to_user(db: Session, user_id: str, title: str, body: str, data: dict[str, str | None]) -> str | None:
    """Sends to every device registered for this user. Never raises: a push send failure must
    never fail the request that's also writing the real, authoritative in-app notification.

    Returns "sent" (at least one device got it), "failed" (every attempt failed), or None
    (nothing to report: FCM isn't configured, or the user has no registered device) -- stored
    on the Notification row as `push_status`, purely for admin-visible delivery monitoring."""
    app = _app()
    if app is None:
        global _warned_unconfigured
        if not _warned_unconfigured:
            log.warning("FCM is not configured (FCM_SERVICE_ACCOUNT_JSON unset) -- push notifications are disabled; in-app notifications are unaffected")
            _warned_unconfigured = True
        return None
    tokens = list(db.scalars(select(DeviceToken).where(DeviceToken.user_id == user_id)))
    if not tokens:
        return None

    from firebase_admin import messaging

    payload = {k: str(v) for k, v in data.items() if v is not None}
    channel_id, priority = _channel_for(data.get("type"))
    sent_any = False
    failed_any = False
    for t in tokens:
        message = messaging.Message(
            token=t.token,
            notification=messaging.Notification(title=title, body=body),
            data=payload,
            android=messaging.AndroidConfig(priority=priority, notification=messaging.AndroidNotification(channel_id=channel_id)),
        )
        try:
            messaging.send(message, app=app)
            sent_any = True
        except messaging.UnregisteredError:
            db.delete(t)  # the device uninstalled or the token expired; stop trying it
        except Exception:
            failed_any = True
            log.exception("push send failed user_id=%s", user_id)
    if sent_any:
        return "sent"
    if failed_any:
        return "failed"
    return None  # every token was stale and removed; nothing left to call a failure
