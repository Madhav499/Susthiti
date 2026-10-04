# 🩺 SUSTHITI

### AI-Powered Longitudinal Digital Health Management Platform

SUSTHITI is a full-stack digital health platform built as a final-year academic project. It brings patient health records, medical reports, lifestyle tracking, risk-screening models, AI-assisted explanations, doctor access control, notifications, and longitudinal health history into one application.

> **Core principle: The database is the source of truth. AI explains the data; AI never becomes the data.**

> ⚠️ **Medical disclaimer:** SUSTHITI is an academic/software project. AI outputs and ML risk results are informational/screening signals only and do not replace a qualified medical professional, diagnosis, treatment, or emergency care.

---

## ✨ Key Features

### 👤 Patient
- Personal health profile and longitudinal history
- Medical report upload with original-file preservation
- Structured report values and health facts
- Glucose and food tracking
- Lifestyle tracking: steps, sleep, activity, heart rate, blood pressure and SpO₂
- Daily, weekly, monthly and custom trend views
- Diabetes Risk screening
- Heart Risk screening
- AI report, patient and lifestyle summaries
- In-app + Android system notifications
- Lifestyle reminders
- AI-summary PDF generation/sharing
- Doctor access approval, rejection and revocation
- Patient ID + QR access workflow

### 👨‍⚕️ Doctor
- Admin-created doctor accounts
- Patient lookup and access requests
- QR scanning to pre-fill patient access requests
- Access only after patient approval
- Patient reports, assessments and longitudinal records
- Permitted visits, prescriptions, follow-ups and doctor responses

### 🛡️ Admin
- Doctor and patient account management
- Access relationship management
- Audit-log visibility
- Application settings
- Administrative patient/doctor profile access
- Permitted report upload on behalf of patients
- Backend-enforced administrative authorization

---

# 🧠 AI Layer

SUSTHITI uses an external LLM through **OpenRouter**. The provider key is stored only on the backend and is never shipped to Flutter.

AI features include:

- Medical report summaries
- Longitudinal patient summaries
- Patient-friendly explanations
- Lifestyle insights
- Risk-assessment interpretation
- Structured health-data comparison

### AI safety

- Original medical records are never replaced by AI output.
- AI summaries are stored separately from source records.
- Backend-computed numbers are authoritative.
- AI cannot invent missing measurements.
- AI cannot prescribe or change medication.
- AI is not used to establish a diagnosis with certainty.
- AI is not used to declare an emergency.
- AI responses pass deterministic backend safety validation.
- Regeneration creates a new AI result rather than overwriting the source record.

See [`AI_ARCHITECTURE.md`](AI_ARCHITECTURE.md).

---

# 🤖 Machine Learning

SUSTHITI contains two independent FastAPI model services.

### Diabetes Risk — `diabetes_risk_api/`

- SUSTHITI Unified Future Diabetes Risk API v4
- Supplied `unified_future_diabetes_model.joblib`
- Backend builds model inputs only from genuinely known data
- Results are stored with provenance
- Output is a screening/model classification signal, not a diagnosis

### Heart Risk — `heart_risk_api/`

- Model version: `susthiti-heart-v3`
- 59 model features
- Reduced 200-tree artifact used for the free-tier deployment footprint
- Trained on synthetic data
- Academic/software screening only
- **Not clinically validated and not a medical diagnosis**

See [`ML_MODEL_SETUP.md`](ML_MODEL_SETUP.md).

---

# 📱 Lifestyle & Longitudinal Tracking

SUSTHITI keeps health information over time rather than treating each report as an isolated event.

Tracked data includes:

- Steps
- Sleep
- Activity
- Heart rate
- Blood pressure
- SpO₂
- Glucose
- Food entries
- Wearable synchronization information

Trend ranges:

- **Today**
- **Week**
- **Month**
- **Custom date range**

Historical data remains stored while a new day's current state starts independently.

---

# 🔔 Notifications & FCM

SUSTHITI supports both in-app notifications and Android system notifications using **Firebase Cloud Messaging**.

Supported notification flows include:

- Doctor access requests
- Lifestyle reminders
- Follow-up reminders
- Other application events

Notification taps support deep-link routing to relevant application sections, including lifestyle metrics. Cold-start notification handling waits for session restoration before routing when necessary.

Firebase service-account credentials are kept in the deployment environment and are not committed to Git.

---

# 📷 Patient QR Access

```text
Patient shows QR
       ↓
Doctor scans QR
       ↓
Patient name + Patient ID pre-filled
       ↓
Doctor selects "Request Access"
       ↓
Patient receives in-app + push notification
       ↓
Patient approves / rejects
       ↓
Approved relationship permits authorized access
```

The QR code does **not** grant access by itself. The backend still requires the patient's approval.

---

# 🏗️ Architecture

```text
Flutter App (Patient / Doctor / Admin)
                 │ HTTPS + JWT
                 ▼
          ┌─────────────────┐
          │ FastAPI Backend │
          │ Auth / RBAC     │
          │ Reports / AI    │
          │ FCM / Records   │
          └───────┬─────────┘
                  │
          ┌───────┴────────┐
          ▼                ▼
   Diabetes ML API    Heart ML API
      FastAPI            FastAPI
          │                │
          └───────┬────────┘
                  ▼
             PostgreSQL
          Source of Truth
                  │
                  ▼
             OpenRouter
                  │
                  ▼
            AI explanation
```

The Flutter app does not call OpenRouter directly. AI and ML requests go through the backend.

---

# 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter + Dart |
| State | Riverpod |
| Routing | go_router |
| HTTP | Dio |
| Charts | fl_chart |
| Secure storage | flutter_secure_storage |
| QR | qr_flutter + mobile_scanner |
| Health data | Health Connect / wearable abstraction |
| Push | Firebase Cloud Messaging |
| Backend | Python + FastAPI |
| ORM | SQLAlchemy |
| Production DB | PostgreSQL |
| Local DB | SQLite |
| AI gateway | OpenRouter |
| ML serving | FastAPI + scikit-learn/joblib |
| PDF | ReportLab |
| Auth | JWT + database-backed sessions |
| Password hashing | bcrypt |
| Deployment | Docker + Render |
| Version control | Git + GitHub |

---

# 📂 Repository Structure

```text
Susthiti/
├── app/                         # Flutter application
├── backend/                     # FastAPI backend
├── diabetes_risk_api/           # Diabetes ML service
├── heart_risk_api/              # Heart ML service
├── deploy/                      # Docker/deployment configuration
├── docs/                        # Supporting documentation
├── PROJECT_EXPLANATION.md
├── ARCHITECTURE.md
├── AI_ARCHITECTURE.md
├── AI_SETUP.md
├── API_SETUP.md
├── DATABASE.md
├── DEPLOY.md
├── ENVIRONMENT_SETUP.md
├── ML_MODEL_SETUP.md
├── SECURITY.md
├── TESTING.md
├── CHANGELOG.md
└── README.md
```

---

# 🔐 Security

Implemented security controls include:

- JWT authentication
- Database-backed revocable sessions
- Role-based access control
- Patient/doctor relationship authorization
- Patient approval before doctor access
- Backend authorization on protected requests
- bcrypt password hashing
- Environment-only secrets
- Git secret-hygiene checks
- Private report storage
- File type/size validation
- SHA-256 file integrity handling
- Audit logging
- No sensitive request-body logging
- Production rejection of weak JWT secrets
- Protection against development reset-token exposure
- AI/risk endpoint rate limiting
- AI output safety validation
- Firebase private key kept outside Git
- `.env`, databases, signing keys and local model environments excluded from Git

### Current AI/risk rate limits

- AI generation: **10 requests / 10 minutes / authenticated user**
- Diabetes risk: **6 requests / 10 minutes / authenticated user**
- Heart risk: **6 requests / 10 minutes / authenticated user**

The current limiter is intentionally lightweight and in-memory for the single-instance showcase deployment.

See [`SECURITY.md`](SECURITY.md) and [`docs/rate-limiting.md`](docs/rate-limiting.md).

---

# 🗄️ Database

Production uses PostgreSQL. Structured data covers users, sessions, patients, doctors, access requests, reports, report values, AI summaries, diabetes/heart assessments, lifestyle metrics, glucose, food, prescriptions, side effects, surgeries, visits, follow-ups, wearables, notifications, device tokens, preferences, appointment recommendations and audit logs.

Medical history follows an append-oriented design. AI summaries are stored separately from source clinical records and regeneration does not overwrite source data.

See [`DATABASE.md`](DATABASE.md).

---

# ☁️ Current Showcase Deployment

The external showcase deployment uses Render Free-tier services:

| Service | Purpose |
|---|---|
| `susthiti` | Main FastAPI backend |
| `susthiti-diabetes-ml` | Diabetes ML service |
| `susthiti-heart-ml` | Heart ML service |
| `susthiti-db` | PostgreSQL database |

The backend health check verifies both ML services. The current production health state is designed to report:

```json
{
  "status": "ok",
  "ai_configured": true,
  "model_service": "ok",
  "model_version": "4.0.0",
  "heart_model_service": "ok",
  "heart_model_version": "susthiti-heart-v3"
}
```

This is a **viva/showcase deployment**, not a production healthcare deployment. Free-tier services can sleep after inactivity and may have cold-start latency and other resource limitations.

---

# 🚀 Local Development

Requirements:

- Python 3.11+
- Flutter/Dart compatible with the project SDK
- Android Studio for Android development
- Git
- PostgreSQL for production-like testing, or SQLite for simple local development

On Windows, the repository includes:

```text
start-susthiti.bat
stop-susthiti.bat
```

Typical local stack:

```text
Flutter :8080
    ↓
FastAPI :8000
    ├── Diabetes ML :8001
    └── Heart ML :8002
```

For detailed setup see [`API_SETUP.md`](API_SETUP.md) and [`ENVIRONMENT_SETUP.md`](ENVIRONMENT_SETUP.md).

---

# 📦 Android Release

Current Flutter application configuration:

```text
Version: 1.0.1
Build: 2002
Package: com.susthiti.susthiti
```

Build the release APK with:

```powershell
scripts\build-release.bat https://YOUR-DOMAIN
```

The release keystore is intentionally excluded from Git. The same signing key must be retained for future Android updates.

---

# 🧪 Testing

Backend:

```bash
cd backend
python -m pytest
```

Flutter:

```bash
cd app
flutter analyze
flutter test
```

The project includes focused tests for authorization, AI behavior, risk models, notification routing, FCM configuration and rate limiting.

See [`TESTING.md`](TESTING.md).

---

# 📚 Documentation

| Document | Purpose |
|---|---|
| [`PROJECT_EXPLANATION.md`](PROJECT_EXPLANATION.md) | Product concept and core principles |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Technical architecture and security model |
| [`AI_ARCHITECTURE.md`](AI_ARCHITECTURE.md) | AI pipeline and safety controls |
| [`AI_SETUP.md`](AI_SETUP.md) | AI provider configuration |
| [`API_SETUP.md`](API_SETUP.md) | Backend/API setup |
| [`DATABASE.md`](DATABASE.md) | Database design and data integrity |
| [`DEPLOY.md`](DEPLOY.md) | Deployment architecture |
| [`ENVIRONMENT_SETUP.md`](ENVIRONMENT_SETUP.md) | Environment configuration |
| [`ML_MODEL_SETUP.md`](ML_MODEL_SETUP.md) | Diabetes and Heart model setup |
| [`SECURITY.md`](SECURITY.md) | Security architecture and audit notes |
| [`docs/rate-limiting.md`](docs/rate-limiting.md) | AI/risk rate-limiting policy |
| [`TESTING.md`](TESTING.md) | Test strategy and commands |
| [`CHANGELOG.md`](CHANGELOG.md) | Project changes and milestones |

---

# 🎓 Academic Project Context

SUSTHITI demonstrates the integration of:

- Mobile application development
- REST API development
- Authentication and authorization
- Relational database design
- Machine learning model serving
- Generative AI integration
- Healthcare-oriented data modelling
- Longitudinal tracking
- Push notifications
- QR-based access workflows
- PDF generation
- Docker/cloud deployment
- Security engineering
- Automated testing

The architecture deliberately separates **stored health facts**, **deterministic calculations**, **ML screening signals**, and **AI-generated explanations**.

---

# 🔮 Future Scope

Potential future improvements include:

- Distributed production-grade rate limiting
- Stronger private-network isolation for ML services
- Managed object storage for medical files
- Automated database migrations
- Automated backups and restore workflows
- More robust wearable integrations
- Additional clinically validated models
- Formal clinical validation and external medical review
- Production observability and monitoring
- Production email/password-reset delivery
- Larger-scale infrastructure
- Formal healthcare privacy/compliance processes

These are future improvements and are **not claimed as completed features** of the current academic showcase.

---

# 👨‍💻 Project

**SUSTHITI — AI-Powered Longitudinal Digital Health Management Platform**

Built as a final-year B.Tech Information Technology project.

Repository: https://github.com/Madhav499/Susthiti

---

## ⚠️ Final Safety Notice

SUSTHITI is an academic software project and must not be used as a substitute for professional medical care. Its AI features provide informational explanations, while its Diabetes and Heart components are screening/model outputs with explicit limitations. Always consult a qualified healthcare professional for medical decisions.
