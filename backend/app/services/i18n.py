"""Backend-side locale support: the set of supported UI languages, and deterministic
(non-AI) notification templates. Each notification type that has a template here is
rendered in the recipient's own preferred_locale -- never the actor's -- so a Gujarati
patient and an English-reading doctor each get their own notification language
independently. A type without a template (or a locale without data for it) falls back to
the English title/body the caller already built, so nothing regresses.
"""

from typing import Literal

SUPPORTED_LOCALES = ("en", "hi", "gu")
DEFAULT_LOCALE = "en"

Locale = Literal["en", "hi", "gu"]


def normalize_locale(value: str | None) -> str:
    """Safe fallback for a missing, null, or unsupported locale -- always English."""
    if value in SUPPORTED_LOCALES:
        return value
    return DEFAULT_LOCALE


LANGUAGE_NAMES: dict[str, str] = {
    "en": "English",
    "hi": "Hindi (हिन्दी)",
    "gu": "Gujarati (ગુજરાતી)",
}

# AISummary's fixed, non-AI-generated disclaimer, appended to every summary's content in
# routers/ai.py's _store(). Deterministic (not run through the AI translation pass) --
# a safety-critical fixed string is translated once, by a person, not regenerated per call.
DISCLAIMER_BY_LOCALE: dict[str, str] = {
    "en": "AI-generated informational summary. This does not replace professional medical judgment.",
    "hi": "यह जानकारी AI द्वारा तैयार की गई है। यह डॉक्टर की पेशेवर सलाह का विकल्प नहीं है।",
    "gu": "આ માહિતી AI દ્વારા તૈયાર કરવામાં આવી છે. તે ડૉક્ટરની વ્યાવસાયિક સલાહનો વિકલ્પ નથી.",
}


def localized_disclaimer(locale: str | None) -> str:
    return DISCLAIMER_BY_LOCALE.get(normalize_locale(locale), DISCLAIMER_BY_LOCALE[DEFAULT_LOCALE])


# type -> locale -> (title_template, body_template). Templates use str.format() with the
# keyword arguments the call site passes as `template_params`. Keep placeholders identical
# across locales for a given type.
_TEMPLATES: dict[str, dict[str, tuple[str, str]]] = {
    "access_request": {
        "en": ("Doctor access request", "Dr. {doctor_name} has requested access to your health records."),
        "hi": ("डॉक्टर एक्सेस रिक्वेस्ट", "डॉ. {doctor_name} ने आपके हेल्थ रिकॉर्ड देखने की अनुमति माँगी है।"),
        "gu": ("ડૉક્ટર એક્સેસ રિક્વેસ્ટ", "ડૉ. {doctor_name} એ તમારા હેલ્થ રેકોર્ડ જોવાની પરવાનગી માંગી છે."),
    },
    "access_approved": {
        "en": ("Access approved", "{patient_name} ({patient_code}) approved your access request."),
        "hi": ("एक्सेस स्वीकृत", "{patient_name} ({patient_code}) ने आपकी एक्सेस रिक्वेस्ट स्वीकार कर ली है।"),
        "gu": ("એક્સેસ મંજૂર", "{patient_name} ({patient_code}) એ તમારી એક્સેસ રિક્વેસ્ટ મંજૂર કરી છે."),
    },
    "access_rejected": {
        "en": ("Access request declined", "{patient_code} declined your access request."),
        "hi": ("एक्सेस रिक्वेस्ट अस्वीकृत", "{patient_code} ने आपकी एक्सेस रिक्वेस्ट अस्वीकार कर दी है।"),
        "gu": ("એક્સેસ રિક્વેસ્ટ નકારાઈ", "{patient_code} એ તમારી એક્સેસ રિક્વેસ્ટ નકારી છે."),
    },
    "access_revoked": {
        "en": ("Access revoked", "Your access to {patient_code} has been revoked."),
        "hi": ("एक्सेस रद्द", "{patient_code} पर आपकी एक्सेस रद्द कर दी गई है।"),
        "gu": ("એક્સેસ રદ", "{patient_code} પર તમારી એક્સેસ રદ કરવામાં આવી છે."),
    },
    "report_summary_ready": {
        "en": ("Report summary ready", "The AI summary for report {report_code} is ready."),
        "hi": ("रिपोर्ट समरी तैयार", "रिपोर्ट {report_code} की AI समरी तैयार है।"),
        "gu": ("રિપોર્ટ સમરી તૈયાર", "રિપોર્ટ {report_code} ની AI સમરી તૈયાર છે."),
    },
    "all_reports_summary_ready": {
        "en": ("Report summary ready", "Your all-reports AI summary is ready."),
        "hi": ("रिपोर्ट समरी तैयार", "आपकी सभी रिपोर्ट्स की AI समरी तैयार है।"),
        "gu": ("રિપોર્ટ સમરી તૈયાર", "તમારી બધી રિપોર્ટ્સની AI સમરી તૈયાર છે."),
    },
    "appointment_recommendation": {
        "en": ("Appointment recommended", "Dr. {doctor_name} recommends an appointment."),
        "hi": ("अपॉइंटमेंट की सलाह", "डॉ. {doctor_name} ने अपॉइंटमेंट लेने की सलाह दी है।"),
        "gu": ("એપોઇન્ટમેન્ટ ભલામણ", "ડૉ. {doctor_name} એ એપોઇન્ટમેન્ટ લેવાની સલાહ આપી છે."),
    },
    "appointment_recommendation_for_side_effect": {
        "en": ("Appointment recommended", "Dr. {doctor_name} recommends an appointment about your reported side effect."),
        "hi": ("अपॉइंटमेंट की सलाह", "डॉ. {doctor_name} ने आपकी साइड-इफ़ेक्ट रिपोर्ट को लेकर अपॉइंटमेंट की सलाह दी है।"),
        "gu": ("એપોઇન્ટમેન્ટ ભલામણ", "ડૉ. {doctor_name} એ તમારા સાઇડ-ઇફેક્ટ રિપોર્ટ અંગે એપોઇન્ટમેન્ટની સલાહ આપી છે."),
    },
    "doctor_response": {
        "en": ("Doctor responded", "Dr. {doctor_name} responded to your side-effect report: {response_label}."),
        "hi": ("डॉक्टर का जवाब", "डॉ. {doctor_name} ने आपकी साइड-इफ़ेक्ट रिपोर्ट पर जवाब दिया: {response_label}।"),
        "gu": ("ડૉક્ટરનો જવાબ", "ડૉ. {doctor_name} એ તમારા સાઇડ-ઇફેક્ટ રિપોર્ટ પર જવાબ આપ્યો: {response_label}."),
    },
    "visit_recorded": {
        "en": ("Visit recorded", "Dr. {doctor_name} recorded your visit on {visit_date}."),
        "hi": ("विज़िट दर्ज", "डॉ. {doctor_name} ने आपकी {visit_date} की विज़िट दर्ज की है।"),
        "gu": ("વિઝિટ નોંધાઈ", "ડૉ. {doctor_name} એ તમારી {visit_date} ની વિઝિટ નોંધી છે."),
    },
    "new_prescription": {
        "en": ("New prescription", "Dr. {doctor_name} created prescription {prescription_code}."),
        "hi": ("नया प्रिस्क्रिप्शन", "डॉ. {doctor_name} ने प्रिस्क्रिप्शन {prescription_code} बनाया है।"),
        "gu": ("નવું પ્રિસ્ક્રિપ્શન", "ડૉ. {doctor_name} એ પ્રિસ્ક્રિપ્શન {prescription_code} બનાવ્યું છે."),
    },
    "follow_up_scheduled": {
        "en": ("Follow-up scheduled", "Dr. {doctor_name} scheduled a follow-up for {due_date}: {purpose}"),
        "hi": ("फॉलो-अप शेड्यूल हुआ", "डॉ. {doctor_name} ने {due_date} के लिए फॉलो-अप शेड्यूल किया: {purpose}"),
        "gu": ("ફોલો-અપ શેડ્યૂલ થયું", "ડૉ. {doctor_name} એ {due_date} માટે ફોલો-અપ શેડ્યૂલ કર્યું: {purpose}"),
    },
    "follow_up_cancelled": {
        "en": ("Follow-up cancelled", "Dr. {doctor_name} cancelled the follow-up planned for {due_date}."),
        "hi": ("फॉलो-अप रद्द", "डॉ. {doctor_name} ने {due_date} के लिए तय फॉलो-अप रद्द कर दिया है।"),
        "gu": ("ફોલો-અપ રદ", "ડૉ. {doctor_name} એ {due_date} માટે નક્કી ફોલો-અપ રદ કર્યું છે."),
    },
    "follow_up_rescheduled": {
        "en": ("Follow-up rescheduled", "Dr. {doctor_name} moved your follow-up to {due_date}."),
        "hi": ("फॉलो-अप फिर से शेड्यूल हुआ", "डॉ. {doctor_name} ने आपका फॉलो-अप {due_date} पर कर दिया है।"),
        "gu": ("ફોલો-અપ ફરી શેડ્યૂલ થયું", "ડૉ. {doctor_name} એ તમારું ફોલો-અપ {due_date} પર ખસેડ્યું છે."),
    },
    "new_report_for_doctor": {
        "en": ("New report", "{patient_name} ({patient_code}) uploaded a new report."),
        "hi": ("नई रिपोर्ट", "{patient_name} ({patient_code}) ने एक नई रिपोर्ट अपलोड की है।"),
        "gu": ("નવી રિપોર્ટ", "{patient_name} ({patient_code}) એ નવી રિપોર્ટ અપલોડ કરી છે."),
    },
    "new_report_for_patient": {
        "en": ("New report added", "A new report was added to your record by {actor_name} ({actor_role})."),
        "hi": ("नई रिपोर्ट जोड़ी गई", "{actor_name} ({actor_role}) ने आपके रिकॉर्ड में एक नई रिपोर्ट जोड़ी है।"),
        "gu": ("નવી રિપોર્ટ ઉમેરાઈ", "{actor_name} ({actor_role}) એ તમારા રેકોર્ડમાં નવી રિપોર્ટ ઉમેરી છે."),
    },
    "surgery_scheduled": {
        "en": ("Surgery scheduled", "Dr. {doctor_name} scheduled a surgery{when}: {name}."),
        "hi": ("सर्जरी शेड्यूल हुई", "डॉ. {doctor_name} ने सर्जरी शेड्यूल की है{when}: {name}।"),
        "gu": ("સર્જરી શેડ્યૂલ થઈ", "ડૉ. {doctor_name} એ સર્જરી શેડ્યૂલ કરી છે{when}: {name}."),
    },
    "surgery_rescheduled": {
        "en": ("Surgery rescheduled", "Dr. {doctor_name} moved your surgery ({name}) to {scheduled_at}."),
        "hi": ("सर्जरी फिर से शेड्यूल हुई", "डॉ. {doctor_name} ने आपकी सर्जरी ({name}) {scheduled_at} पर कर दी है।"),
        "gu": ("સર્જરી ફરી શેડ્યૂલ થઈ", "ડૉ. {doctor_name} એ તમારી સર્જરી ({name}) {scheduled_at} પર ખસેડી છે."),
    },
    "surgery_cancelled": {
        "en": ("Surgery cancelled", "Dr. {doctor_name} cancelled the surgery planned for {name}."),
        "hi": ("सर्जरी रद्द", "डॉ. {doctor_name} ने {name} के लिए तय सर्जरी रद्द कर दी है।"),
        "gu": ("સર્જરી રદ", "ડૉ. {doctor_name} એ {name} માટે નક્કી સર્જરી રદ કરી છે."),
    },
}


_RESPONSE_LABELS: dict[str, dict[str, str]] = {
    "en": {
        "no_immediate_action": "No immediate action",
        "monitor": "Monitor",
        "contact_doctor": "Contact doctor",
        "appointment_recommended": "Appointment recommended",
        "urgent_medical_attention": "Urgent medical attention",
    },
    "hi": {
        "no_immediate_action": "अभी कोई कार्रवाई नहीं",
        "monitor": "नज़र रखें",
        "contact_doctor": "डॉक्टर से संपर्क करें",
        "appointment_recommended": "अपॉइंटमेंट की सलाह",
        "urgent_medical_attention": "तुरंत मेडिकल सहायता लें",
    },
    "gu": {
        "no_immediate_action": "હાલ કોઈ પગલાંની જરૂર નથી",
        "monitor": "ધ્યાન રાખો",
        "contact_doctor": "ડૉક્ટરનો સંપર્ક કરો",
        "appointment_recommended": "એપોઇન્ટમેન્ટની ભલામણ",
        "urgent_medical_attention": "તાત્કાલિક મેડિકલ સહાય લો",
    },
}


def response_label(response_type: str, locale: str) -> str:
    by_locale = _RESPONSE_LABELS.get(normalize_locale(locale), _RESPONSE_LABELS[DEFAULT_LOCALE])
    return by_locale.get(response_type, _RESPONSE_LABELS[DEFAULT_LOCALE].get(response_type, response_type))


_ROLE_LABELS: dict[str, dict[str, str]] = {
    "en": {"patient": "patient", "doctor": "doctor", "admin": "administrator"},
    "hi": {"patient": "मरीज़", "doctor": "डॉक्टर", "admin": "एडमिन"},
    "gu": {"patient": "દર્દી", "doctor": "ડૉક્ટર", "admin": "એડમિન"},
}


def role_label(role: str, locale: str) -> str:
    by_locale = _ROLE_LABELS.get(normalize_locale(locale), _ROLE_LABELS[DEFAULT_LOCALE])
    return by_locale.get(role, role)


# Password-reset email (services/email.py). The reset code itself is always a bare 8-digit
# number -- never translated, never reformatted -- so there is no clinical-safety concern
# here the way there is for AI content; this is a hand-translated fixed template.
PASSWORD_RESET_EMAIL: dict[str, dict[str, str]] = {
    "en": {
        "subject": "SUSTHITI Password Reset",
        "greeting": "Hello {name},",
        "intro": "We received a request to reset your SUSTHITI account password.",
        "code_label": "Your password reset code is:",
        "expiry": "This code expires after {minutes} minutes.",
        "ignore": "If you did not request this password reset, you can safely ignore this email.",
        "warning": "For security, do not share this code with anyone.",
        "regards": "Regards,",
        "team": "SUSTHITI Team",
    },
    "hi": {
        "subject": "SUSTHITI पासवर्ड रीसेट",
        "greeting": "नमस्ते {name},",
        "intro": "हमें आपके SUSTHITI खाते का पासवर्ड रीसेट करने की रिक्वेस्ट मिली है।",
        "code_label": "आपका पासवर्ड रीसेट कोड है:",
        "expiry": "यह कोड {minutes} मिनट के बाद काम करना बंद कर देगा।",
        "ignore": "अगर आपने यह रिक्वेस्ट नहीं की है, तो इस ईमेल को नज़रअंदाज़ करें।",
        "warning": "सुरक्षा के लिए, यह कोड किसी के साथ साझा न करें।",
        "regards": "धन्यवाद,",
        "team": "SUSTHITI टीम",
    },
    "gu": {
        "subject": "SUSTHITI પાસવર્ડ રીસેટ",
        "greeting": "નમસ્તે {name},",
        "intro": "અમને તમારા SUSTHITI ખાતાનો પાસવર્ડ રીસેટ કરવાની રિક્વેસ્ટ મળી છે.",
        "code_label": "તમારો પાસવર્ડ રીસેટ કોડ છે:",
        "expiry": "આ કોડ {minutes} મિનિટ પછી કામ કરવાનું બંધ કરશે.",
        "ignore": "જો તમે આ રિક્વેસ્ટ નથી કરી, તો આ ઈમેલને અવગણો.",
        "warning": "સુરક્ષા માટે, આ કોડ કોઈની સાથે શેર ન કરો.",
        "regards": "આભાર,",
        "team": "SUSTHITI ટીમ",
    },
}


def password_reset_email_text(locale: str) -> dict[str, str]:
    return PASSWORD_RESET_EMAIL.get(normalize_locale(locale), PASSWORD_RESET_EMAIL[DEFAULT_LOCALE])


def localized_notification(type_: str, locale: str, params: dict) -> tuple[str, str] | None:
    """Renders the (title, body) for a notification `type_` in `locale`, or None when no
    template exists (caller keeps its own English title/body as the fallback)."""
    by_locale = _TEMPLATES.get(type_)
    if by_locale is None:
        return None
    template = by_locale.get(normalize_locale(locale)) or by_locale.get(DEFAULT_LOCALE)
    if template is None:
        return None
    title_template, body_template = template
    try:
        return title_template.format(**params), body_template.format(**params)
    except (KeyError, IndexError):
        return None
