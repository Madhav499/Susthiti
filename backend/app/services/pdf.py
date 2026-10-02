"""PDFService: renders stored AI summaries in the SUSTHITI style (calm, teal accent)."""

from datetime import datetime
from io import BytesIO
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import HRFlowable, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

from .ai.gemini import DISCLAIMER

TEAL = colors.HexColor("#176B67")
TEXT = colors.HexColor("#18302F")
MUTED = colors.HexColor("#667775")
BORDER = colors.HexColor("#DDE7E4")
SOFT = colors.HexColor("#E4F3F1")

TITLES = {
    "individual_report": "Individual Report Summary",
    "all_reports": "All Reports Summary",
    "patient_summary": "AI Patient Summary",
    "lifestyle": "Lifestyle Insight",
    "assessment_interpretation": "Assessment Interpretation",
}
FILE_LABELS = {
    "individual_report": "Individual_Report_Summary",
    "all_reports": "All_Reports_Summary",
    "patient_summary": "Patient_Summary",
    "lifestyle": "Lifestyle_Insight",
    "assessment_interpretation": "Assessment_Interpretation",
}

# Section order and labels per summary kind.
SECTIONS = {
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
        ("patient_overview", "Patient overview"),
        ("diabetes_history", "Diabetes history"),
        ("recent_assessments", "Recent assessments"),
        ("medical_reports", "Medical reports"),
        ("relevant_trends", "Relevant trends"),
        ("glucose_history", "Glucose history"),
        ("lifestyle_trends", "Lifestyle trends"),
        ("medication_history", "Medication / prescription history"),
        ("side_effects", "Side effects"),
        ("doctor_visits", "Doctor visits"),
        ("recent_developments", "Recent developments"),
        ("items_to_discuss", "Items to discuss with patient"),
        ("interpretation", "AI interpretation"),
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
}


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


def _render_value(value, styles) -> list:
    if value in (None, "", [], {}):
        return [Paragraph("Not available.", styles["muted"])]
    if isinstance(value, str):
        return [Paragraph(_text(value), styles["body"])]
    if isinstance(value, dict):
        rows = [[Paragraph(_text(k.replace("_", " ").capitalize()), styles["muted"]), Paragraph(_text(v or "Not available"), styles["body"])] for k, v in value.items()]
        return [_table(rows)]
    flow = []
    for item in value:
        if isinstance(item, dict):
            if "parameter" in item:  # trend
                earlier = item.get("earlier") or {}
                latest = item.get("latest") or {}
                line = (
                    f"<b>{_text(item['parameter'])}</b>: earlier {_text(earlier.get('value', '-'))}"
                    f" ({_text(earlier.get('date', '-'))}), latest {_text(latest.get('value', '-'))}"
                    f" ({_text(latest.get('date', '-'))}). {_text(item.get('observed_change', ''))}"
                )
            elif "name" in item:  # relevant value
                parts = [f"<b>{_text(item['name'])}</b>: {_text(item.get('value', ''))} {_text(item.get('unit') or '')}"]
                if item.get("reference_range"):
                    parts.append(f"(reference {_text(item['reference_range'])})")
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
) -> bytes:
    styles = _styles()
    buffer = BytesIO()

    def footer(canvas, doc):
        canvas.saveState()
        canvas.setStrokeColor(BORDER)
        canvas.line(18 * mm, 16 * mm, A4[0] - 18 * mm, 16 * mm)
        canvas.setFont("Helvetica", 8)
        canvas.setFillColor(MUTED)
        canvas.drawString(18 * mm, 11 * mm, DISCLAIMER)
        canvas.drawRightString(A4[0] - 18 * mm, 11 * mm, f"Page {doc.page}")
        canvas.restoreState()

    doc = SimpleDocTemplate(
        buffer, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=18 * mm, bottomMargin=24 * mm,
        title=f"SUSTHITI {TITLES.get(kind, 'Summary')}", author="SUSTHITI",
    )
    story = [
        Paragraph("SUSTHITI", styles["brand"]),
        HRFlowable(width="100%", thickness=1.2, color=TEAL, spaceBefore=4, spaceAfter=10),
        Paragraph(TITLES.get(kind, "Summary"), styles["title"]),
        Paragraph("AI-generated", styles["muted"]),
        Spacer(1, 8),
        _table(
            [
                [Paragraph("Patient", styles["muted"]), Paragraph(_text(patient.get("name", "")), styles["body"])],
                [Paragraph("Patient ID", styles["muted"]), Paragraph(_text(patient.get("code", "")), styles["body"])],
                [Paragraph("Generated", styles["muted"]), Paragraph(generated_at.strftime("%d %b %Y, %H:%M UTC"), styles["body"])],
                [Paragraph("Based on", styles["muted"]), Paragraph(_text(", ".join(based_on) or "Available records"), styles["body"])],
                [Paragraph("AI model", styles["muted"]), Paragraph(_text(model), styles["body"])],
            ]
        ),
    ]
    for key, label in SECTIONS.get(kind, [(k, k.replace("_", " ").capitalize()) for k in content]):
        if key not in content:
            continue
        story.append(Paragraph(label, styles["h"]))
        story.extend(_render_value(content[key], styles))
    story.append(Spacer(1, 12))
    story.append(Paragraph(_text(content.get("disclaimer", DISCLAIMER)), styles["muted"]))
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    return buffer.getvalue()
