"""PDFService: renders stored AI summaries in the SUSTHITI style (calm, teal accent).

CURRENT LIMITATION - PDF FONT SUPPORT:
This module uses ReportLab with Helvetica font, which has NO support for Devanagari (Hindi)
or Gujarati scripts. PDFs generated for Hindi/Gujarati users would show empty boxes (□) for
Indic characters. Therefore, PDF generation currently forces English locale regardless of user
preference to ensure readability. The Flutter UI shows a clear notice to Hindi/Gujarati users
that PDF export is English-only.

To implement proper multilingual PDF support requires:
- Bundle Noto Sans Devanagari and Noto Sans Gujarati fonts (open source, Apache 2.0)
- Register fonts with ReportLab's pdfmetrics.registerFont()
- Implement locale-aware font selection in _styles()
- Verify Indic script shaping (conjuncts, vowel marks) renders correctly
- Test with actual Hindi/Gujarati content and visual inspection

The PDF's static chrome (titles, section headings, field labels) is rendered in the
*viewer's* preferred_locale when font support exists. The summary `content` dict itself is
untouched here: it already carries whatever locale it was generated/translated in by
services/ai/localization.py, and this module never re-translates or alters it. The downloaded
filename (pdf_filename) is deliberately kept English/ASCII regardless of locale: Content-
Disposition filenames with non-ASCII characters need RFC 5987 encoding that not every HTTP
client/browser handles consistently, and the filename is not clinical content a patient reads.
"""

from datetime import datetime
from io import BytesIO
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import HRFlowable, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

from .ai.openrouter import DISCLAIMER
from .i18n import DEFAULT_LOCALE, normalize_locale

TEAL = colors.HexColor("#176B67")
TEXT = colors.HexColor("#18302F")
MUTED = colors.HexColor("#667775")
BORDER = colors.HexColor("#DDE7E4")
SOFT = colors.HexColor("#E4F3F1")

FILE_LABELS = {
    "individual_report": "Individual_Report_Summary",
    "all_reports": "All_Reports_Summary",
    "patient_summary": "Patient_Summary",
    "patient_friendly_summary": "Your_Health_Summary",
    "lifestyle": "Lifestyle_Insight",
    "assessment_interpretation": "Assessment_Interpretation",
    "heart_interpretation": "Heart_Risk_Screening_Interpretation",
}

# Page/heading title per summary kind, by locale.
TITLES: dict[str, dict[str, str]] = {
    "en": {
        "individual_report": "Individual Report Summary",
        "all_reports": "All Reports Summary",
        "patient_summary": "AI Patient Summary",
        "patient_friendly_summary": "Your Health Summary",
        "lifestyle": "Lifestyle Insight",
        "assessment_interpretation": "Assessment Interpretation",
        "heart_interpretation": "Heart Risk Screening Interpretation",
    },
    "hi": {
        "individual_report": "व्यक्तिगत रिपोर्ट सारांश",
        "all_reports": "सभी रिपोर्ट्स का सारांश",
        "patient_summary": "AI मरीज़ सारांश",
        "patient_friendly_summary": "आपका हेल्थ सारांश",
        "lifestyle": "लाइफस्टाइल इनसाइट",
        "assessment_interpretation": "असेसमेंट व्याख्या",
        "heart_interpretation": "हार्ट रिस्क स्क्रीनिंग व्याख्या",
    },
    "gu": {
        "individual_report": "વ્યક્તિગત રિપોર્ટ સારાંશ",
        "all_reports": "બધી રિપોર્ટ્સનો સારાંશ",
        "patient_summary": "AI દર્દી સારાંશ",
        "patient_friendly_summary": "તમારો હેલ્થ સારાંશ",
        "lifestyle": "લાઇફસ્ટાઇલ ઇનસાઇટ",
        "assessment_interpretation": "એસેસમેન્ટ અર્થઘટન",
        "heart_interpretation": "હાર્ટ રિસ્ક સ્ક્રીનિંગ અર્થઘટન",
    },
}

# Section order and labels per summary kind, by locale. Keep keys and ordering identical
# across locales -- only the label (second tuple element) changes.
SECTIONS: dict[str, dict[str, list[tuple[str, str]]]] = {
    "en": {
        "individual_report": [
            ("report_information", "Report information"),
            ("summary", "Summary"),
            ("key_findings", "Key findings"),
            ("relevant_values", "Relevant values"),
            ("observed_trends", "Observed within this report"),
            ("interpretation", "AI interpretation"),
            ("questions_for_doctor", "Questions to discuss with your doctor"),
            ("limitations", "Limitations"),
        ],
        "all_reports": [
            ("summary", "Summary"),
            ("observed_trends", "Observed trends"),
            ("key_findings", "Key findings"),
            ("gaps", "Not enough information to compare"),
            ("interpretation", "AI interpretation"),
            ("questions_for_doctor", "Questions to discuss with your doctor"),
        ],
        "patient_summary": [
            ("current_status", "Current status"),
            ("key_findings", "Key findings"),
            ("trends", "Trends"),
            ("attention_items", "Attention"),
            ("recent_changes", "Recent changes"),
            ("interpretation", "AI interpretation"),
            ("diabetes_history", "Diabetes history"),
            ("recent_assessments", "Recent assessments"),
            ("medical_reports", "Medical reports"),
            ("glucose_history", "Glucose history"),
            ("lifestyle_trends", "Lifestyle trends"),
            ("medication_history", "Medication / prescription history"),
            ("side_effects", "Side effects"),
            ("doctor_visits", "Doctor visits"),
            ("recent_developments", "Recent developments"),
        ],
        "patient_friendly_summary": [
            ("overall", "Overall"),
            ("standouts", "What stands out"),
            ("changes", "What has changed"),
            ("keep_in_mind", "What to keep in mind"),
            ("discuss_with_doctor", "What to discuss with your doctor"),
        ],
        "lifestyle": [
            ("headline", "Overview"),
            ("overview", "Lifestyle overview"),
            ("observations", "Observations"),
            ("suggestions", "AI suggestions"),
            ("interpretation", "AI interpretation"),
        ],
        "assessment_interpretation": [
            ("interpretation", "Interpretation"),
            ("contributing_patterns", "Contributing patterns"),
            ("suggestions", "Suggestions"),
        ],
        "heart_interpretation": [
            ("interpretation", "Interpretation"),
            ("contributing_patterns", "Contributing patterns"),
            ("suggestions", "Suggestions"),
        ],
    },
    "hi": {
        "individual_report": [
            ("report_information", "रिपोर्ट जानकारी"),
            ("summary", "सारांश"),
            ("key_findings", "मुख्य निष्कर्ष"),
            ("relevant_values", "संबंधित वैल्यू"),
            ("observed_trends", "इस रिपोर्ट में देखा गया"),
            ("interpretation", "AI व्याख्या"),
            ("questions_for_doctor", "अपने डॉक्टर से चर्चा करने योग्य सवाल"),
            ("limitations", "सीमाएं"),
        ],
        "all_reports": [
            ("summary", "सारांश"),
            ("observed_trends", "देखे गए रुझान"),
            ("key_findings", "मुख्य निष्कर्ष"),
            ("gaps", "तुलना के लिए पर्याप्त जानकारी नहीं"),
            ("interpretation", "AI व्याख्या"),
            ("questions_for_doctor", "अपने डॉक्टर से चर्चा करने योग्य सवाल"),
        ],
        "patient_summary": [
            ("current_status", "वर्तमान स्थिति"),
            ("key_findings", "मुख्य निष्कर्ष"),
            ("trends", "रुझान"),
            ("attention_items", "ध्यान देने योग्य"),
            ("recent_changes", "हाल के बदलाव"),
            ("interpretation", "AI व्याख्या"),
            ("diabetes_history", "डायबिटीज़ इतिहास"),
            ("recent_assessments", "हाल के असेसमेंट"),
            ("medical_reports", "मेडिकल रिपोर्ट"),
            ("glucose_history", "ग्लूकोज़ इतिहास"),
            ("lifestyle_trends", "लाइफस्टाइल रुझान"),
            ("medication_history", "दवा / प्रिस्क्रिप्शन इतिहास"),
            ("side_effects", "साइड इफ़ेक्ट"),
            ("doctor_visits", "डॉक्टर विज़िट"),
            ("recent_developments", "हाल के घटनाक्रम"),
        ],
        "patient_friendly_summary": [
            ("overall", "कुल मिलाकर"),
            ("standouts", "क्या खास है"),
            ("changes", "क्या बदला है"),
            ("keep_in_mind", "ध्यान रखने योग्य बातें"),
            ("discuss_with_doctor", "अपने डॉक्टर से चर्चा करने योग्य बातें"),
        ],
        "lifestyle": [
            ("headline", "अवलोकन"),
            ("overview", "लाइफस्टाइल अवलोकन"),
            ("observations", "अवलोकन"),
            ("suggestions", "AI सुझाव"),
            ("interpretation", "AI व्याख्या"),
        ],
        "assessment_interpretation": [
            ("interpretation", "व्याख्या"),
            ("contributing_patterns", "योगदान देने वाले पैटर्न"),
            ("suggestions", "सुझाव"),
        ],
        "heart_interpretation": [
            ("interpretation", "व्याख्या"),
            ("contributing_patterns", "योगदान देने वाले पैटर्न"),
            ("suggestions", "सुझाव"),
        ],
    },
    "gu": {
        "individual_report": [
            ("report_information", "રિપોર્ટ માહિતી"),
            ("summary", "સારાંશ"),
            ("key_findings", "મુખ્ય તારણો"),
            ("relevant_values", "સંબંધિત વેલ્યુ"),
            ("observed_trends", "આ રિપોર્ટમાં જોવાયેલ"),
            ("interpretation", "AI અર્થઘટન"),
            ("questions_for_doctor", "તમારા ડૉક્ટર સાથે ચર્ચા કરવા જેવા પ્રશ્નો"),
            ("limitations", "મર્યાદાઓ"),
        ],
        "all_reports": [
            ("summary", "સારાંશ"),
            ("observed_trends", "જોવાયેલ વલણો"),
            ("key_findings", "મુખ્ય તારણો"),
            ("gaps", "સરખામણી માટે પૂરતી માહિતી નથી"),
            ("interpretation", "AI અર્થઘટન"),
            ("questions_for_doctor", "તમારા ડૉક્ટર સાથે ચર્ચા કરવા જેવા પ્રશ્નો"),
        ],
        "patient_summary": [
            ("current_status", "વર્તમાન સ્થિતિ"),
            ("key_findings", "મુખ્ય તારણો"),
            ("trends", "વલણો"),
            ("attention_items", "ધ્યાન આપવા જેવું"),
            ("recent_changes", "તાજેતરના ફેરફારો"),
            ("interpretation", "AI અર્થઘટન"),
            ("diabetes_history", "ડાયાબિટીસ ઇતિહાસ"),
            ("recent_assessments", "તાજેતરના એસેસમેન્ટ"),
            ("medical_reports", "મેડિકલ રિપોર્ટ"),
            ("glucose_history", "ગ્લુકોઝ ઇતિહાસ"),
            ("lifestyle_trends", "લાઇફસ્ટાઇલ વલણો"),
            ("medication_history", "દવા / પ્રિસ્ક્રિપ્શન ઇતિહાસ"),
            ("side_effects", "સાઇડ ઇફેક્ટ"),
            ("doctor_visits", "ડૉક્ટર વિઝિટ"),
            ("recent_developments", "તાજેતરના ઘટનાક્રમ"),
        ],
        "patient_friendly_summary": [
            ("overall", "એકંદરે"),
            ("standouts", "શું ખાસ છે"),
            ("changes", "શું બદલાયું છે"),
            ("keep_in_mind", "ધ્યાનમાં રાખવા જેવી બાબતો"),
            ("discuss_with_doctor", "તમારા ડૉક્ટર સાથે ચર્ચા કરવા જેવી બાબતો"),
        ],
        "lifestyle": [
            ("headline", "ઝાંખી"),
            ("overview", "લાઇફસ્ટાઇલ ઝાંખી"),
            ("observations", "અવલોકનો"),
            ("suggestions", "AI સૂચનો"),
            ("interpretation", "AI અર્થઘટન"),
        ],
        "assessment_interpretation": [
            ("interpretation", "અર્થઘટન"),
            ("contributing_patterns", "યોગદાન આપતી પેટર્ન"),
            ("suggestions", "સૂચનો"),
        ],
        "heart_interpretation": [
            ("interpretation", "અર્થઘટન"),
            ("contributing_patterns", "યોગદાન આપતી પેટર્ન"),
            ("suggestions", "સૂચનો"),
        ],
    },
}

# Fixed chrome words around the content: field labels, placeholders, the footer page number.
CHROME: dict[str, dict[str, str]] = {
    "en": {
        "ai_generated": "AI-generated",
        "patient": "Patient",
        "patient_id": "Patient ID",
        "generated": "Generated",
        "based_on": "Based on",
        "ai_model": "AI model",
        "not_available": "Not available.",
        "available_records": "Available records",
        "page": "Page {page}",
        "reference": "reference {range}",
        "earlier": "earlier",
        "latest": "latest",
        "authorized_patient_record": "Authorized patient record",
    },
    "hi": {
        "ai_generated": "AI-जनित",
        "patient": "मरीज़",
        "patient_id": "मरीज़ ID",
        "generated": "बनाया गया",
        "based_on": "आधारित",
        "ai_model": "AI मॉडल",
        "not_available": "उपलब्ध नहीं।",
        "available_records": "उपलब्ध रिकॉर्ड",
        "page": "पेज {page}",
        "reference": "संदर्भ {range}",
        "earlier": "पहले",
        "latest": "नवीनतम",
        "authorized_patient_record": "अधिकृत मरीज़ रिकॉर्ड",
    },
    "gu": {
        "ai_generated": "AI-જનરેટેડ",
        "patient": "દર્દી",
        "patient_id": "દર્દી ID",
        "generated": "બનાવાયું",
        "based_on": "આધારિત",
        "ai_model": "AI મોડલ",
        "not_available": "ઉપલબ્ધ નથી.",
        "available_records": "ઉપલબ્ધ રેકોર્ડ",
        "page": "પેજ {page}",
        "reference": "સંદર્ભ {range}",
        "earlier": "અગાઉ",
        "latest": "તાજેતરનું",
        "authorized_patient_record": "અધિકૃત દર્દી રેકોર્ડ",
    },
}


def _chrome(locale: str) -> dict[str, str]:
    return CHROME.get(normalize_locale(locale), CHROME[DEFAULT_LOCALE])


def localized_authorized_patient_record(locale: str | None) -> str:
    """The `based_on` placeholder for summary kinds that aren't tied to specific reports
    (patient_summary, lifestyle, interpretations, ...). Used by routers/ai.py's PDF endpoint
    when building `based_on` for render_summary_pdf."""
    return _chrome(locale)["authorized_patient_record"]


def pdf_filename(kind: str, generated_at: datetime) -> str:
    return f"SUSTHITI_{FILE_LABELS.get(kind, 'Summary')}_{generated_at.date().isoformat()}.pdf"


def _styles():
    base = dict(fontName="Helvetica", textColor=TEXT, leading=14, fontSize=10, alignment=TA_LEFT)
    return {
        "brand": ParagraphStyle("brand", **{**base, "fontName": "Helvetica-Bold", "fontSize": 16, "textColor": TEAL, "leading": 20}),
        "title": ParagraphStyle("title", **{**base, "fontName": "Helvetica-Bold", "fontSize": 14, "leading": 18}),
        "h": ParagraphStyle("h", **{**base, "fontName": "Helvetica-Bold", "fontSize": 11, "textColor": TEAL, "spaceBefore": 10, "spaceAfter": 4}),
        "body": ParagraphStyle("body", **base),
        "muted": ParagraphStyle("muted", **{**base, "textColor": MUTED, "fontSize": 9}),
        "bullet": ParagraphStyle("bullet", **{**base, "leftIndent": 10, "bulletIndent": 0}),
    }


def _text(value) -> str:
    return escape(str(value)).replace("\n", "<br/>")


def _render_value(value, styles, chrome: dict[str, str]) -> list:
    if value in (None, "", [], {}):
        return [Paragraph(chrome["not_available"], styles["muted"])]
    if isinstance(value, str):
        return [Paragraph(_text(value), styles["body"])]
    if isinstance(value, dict):
        # Keys here are AI/backend-determined field names (not a fixed UI string SUSTHITI
        # controls), so -- like the enum/model labels left untranslated elsewhere in the app --
        # they are rendered as readable English rather than guessed at in other locales.
        rows = [[Paragraph(_text(k.replace("_", " ").capitalize()), styles["muted"]), Paragraph(_text(v or chrome["not_available"]), styles["body"])] for k, v in value.items()]
        return [_table(rows)]
    flow = []
    for item in value:
        if isinstance(item, dict):
            if "parameter" in item:  # trend
                earlier = item.get("earlier") or {}
                latest = item.get("latest") or {}
                line = (
                    f"<b>{_text(item['parameter'])}</b>: {chrome['earlier']} {_text(earlier.get('value', '-'))}"
                    f" ({_text(earlier.get('date', '-'))}), {chrome['latest']} {_text(latest.get('value', '-'))}"
                    f" ({_text(latest.get('date', '-'))}). {_text(item.get('observed_change', ''))}"
                )
            elif "name" in item:  # relevant value
                parts = [f"<b>{_text(item['name'])}</b>: {_text(item.get('value', ''))} {_text(item.get('unit') or '')}"]
                if item.get("reference_range"):
                    parts.append(f"({chrome['reference'].format(range=_text(item['reference_range']))})")
                if item.get("note"):
                    parts.append(f"- {_text(item['note'])}")
                line = " ".join(parts)
            else:
                line = _text(", ".join(f"{k}: {v}" for k, v in item.items()))
            flow.append(Paragraph(line, styles["bullet"], bulletText="•"))
        else:
            flow.append(Paragraph(_text(item), styles["bullet"], bulletText="•"))
    return flow


def _table(rows) -> Table:
    table = Table(rows, colWidths=[45 * mm, None])
    table.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LINEBELOW", (0, 0), (-1, -1), 0.4, BORDER),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ("LEFTPADDING", (0, 0), (-1, -1), 0),
            ]
        )
    )
    return table


def render_summary_pdf(
    kind: str,
    content: dict,
    patient: dict,
    generated_at: datetime,
    based_on: list[str],
    model: str,
    locale: str | None = None,
) -> bytes:
    locale = normalize_locale(locale)
    chrome = _chrome(locale)
    titles = TITLES.get(locale, TITLES[DEFAULT_LOCALE])
    sections = SECTIONS.get(locale, SECTIONS[DEFAULT_LOCALE])
    styles = _styles()
    buffer = BytesIO()

    def footer(canvas, doc):
        canvas.saveState()
        canvas.setStrokeColor(BORDER)
        canvas.line(18 * mm, 16 * mm, A4[0] - 18 * mm, 16 * mm)
        canvas.setFont("Helvetica", 8)
        canvas.setFillColor(MUTED)
        canvas.drawString(18 * mm, 11 * mm, DISCLAIMER)
        canvas.drawRightString(A4[0] - 18 * mm, 11 * mm, chrome["page"].format(page=doc.page))
        canvas.restoreState()

    doc = SimpleDocTemplate(
        buffer, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=18 * mm, bottomMargin=24 * mm,
        title=f"SUSTHITI {titles.get(kind, 'Summary')}", author="SUSTHITI",
    )
    story = [
        Paragraph("SUSTHITI", styles["brand"]),
        HRFlowable(width="100%", thickness=1.2, color=TEAL, spaceBefore=4, spaceAfter=10),
        Paragraph(titles.get(kind, "Summary"), styles["title"]),
        Paragraph(chrome["ai_generated"], styles["muted"]),
        Spacer(1, 8),
        _table(
            [
                [Paragraph(chrome["patient"], styles["muted"]), Paragraph(_text(patient.get("name", "")), styles["body"])],
                [Paragraph(chrome["patient_id"], styles["muted"]), Paragraph(_text(patient.get("code", "")), styles["body"])],
                [Paragraph(chrome["generated"], styles["muted"]), Paragraph(generated_at.strftime("%d %b %Y, %H:%M UTC"), styles["body"])],
                [Paragraph(chrome["based_on"], styles["muted"]), Paragraph(_text(", ".join(based_on) or chrome["available_records"]), styles["body"])],
                [Paragraph(chrome["ai_model"], styles["muted"]), Paragraph(_text(model), styles["body"])],
            ]
        ),
    ]
    for key, label in sections.get(kind, [(k, k.replace("_", " ").capitalize()) for k in content]):
        if key not in content:
            continue
        story.append(Paragraph(label, styles["h"]))
        story.extend(_render_value(content[key], styles, chrome))
    story.append(Spacer(1, 12))
    story.append(Paragraph(_text(content.get("disclaimer", DISCLAIMER)), styles["muted"]))
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    return buffer.getvalue()
