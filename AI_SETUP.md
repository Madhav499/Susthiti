# AI setup (Google AI Studio)

All AI runs on the **backend**. The Flutter app never holds an API key and never calls Google directly.

## 1. Create a key

1. Open [Google AI Studio](https://aistudio.google.com/) and create an API key for a project you control.
2. Restrict the key in Google Cloud Console (API restriction: Generative Language API).
3. Check the data-use terms for the tier you use. Patient reports are sent to the model when a summary is
   generated, so use a paid tier / agreement appropriate for health data in your jurisdiction.

## 2. Give the key to the backend only

```bash
# backend/.env (git-ignored) for local development
GEMINI_API_KEY=your-key-here
GEMINI_MODEL=gemini-2.5-flash
AI_TIMEOUT_SECONDS=90
```

In production, set `GEMINI_API_KEY` as a secret in your hosting platform instead of a file.

Never:

- put the key in Flutter code (`const apiKey = "AIza..."`), `--dart-define`, or any asset,
- commit `.env` or paste the key into issues, logs or chat,
- log request or response bodies.

The backend sends the key in the `x-goog-api-key` header (not in the URL), and its request log records only
route templates and status codes.

Check it is active: `GET /health` returns `"ai_configured": true`, and Admin → More → System settings shows
"AI (Google AI Studio): Configured".

## 3. What each AI feature does

Four services, each with its own system instruction and a JSON response schema (`backend/app/services/ai/`):

| Service | Question it answers | Input | Where it appears |
| --- | --- | --- | --- |
| `ReportSummaryService` | What does this one report say? | Report metadata + the original file | Report detail |
| `AllReportsSummaryService` | What do the reports show over time? | All authorized reports in report-date order, with their stored summaries and files | Reports → All Reports Summary |
| `PatientSummaryService` | What is this patient's history? | The authorized longitudinal record | AI Patient Summary (patient and doctor) |
| `LifestyleAIService` | What lifestyle changes might help? And how does an assessment relate to recent lifestyle? | Lifestyle, food and glucose data; an assessment | Lifestyle Insight; assessment detail |

Every instruction tells the model to use only the supplied data, not to invent values, to separate observed
information from interpretation, not to prescribe or diagnose with certainty, and not to declare
emergencies. The assessment interpretation must not give a timeframe or probability of developing diabetes.

## 4. Safety handling

- The response is requested as JSON (`responseMimeType: application/json`) and validated against a schema.
  Anything that does not parse returns `ai_invalid_response`. The app shows "We couldn't generate the summary
  right now", reassures that the original records are unchanged, and offers Try Again.
- Missing key returns `ai_not_configured`; the app says AI is not set up and hides Try Again.
- Timeouts and upstream errors return `ai_timeout` / `ai_service_unavailable`.
- Every stored summary carries the disclaimer, the model name, the generation time and the role that
  generated it, and is labelled **AI-generated** in the app.
- Summaries are stored and shown until someone presses Regenerate. When the source records change (a new
  report, for example) the summary is marked as possibly out of date.
- Summaries can be downloaded as a PDF (`SUSTHITI_<Label>_<date>.pdf`). The original report stays available
  next to its summary.

## 5. Changing model

Set `GEMINI_MODEL` to another Gemini model that supports JSON output and file input (PDF and images for
report summaries). Test with a few DEMO reports before switching in production.
