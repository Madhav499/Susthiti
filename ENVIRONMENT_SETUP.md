# Environment setup — index

This is a thin index. Each linked doc covers its own area in full; nothing here duplicates them.

| What you're setting up | Where |
| --- | --- |
| Backend env vars (`JWT_SECRET`, `DATABASE_URL`, `CORS_ORIGINS`, ...), running locally, API endpoints | [API_SETUP.md](API_SETUP.md) |
| Google AI Studio (Gemini) key, model, safety handling | [AI_SETUP.md](AI_SETUP.md) |
| The diabetes risk model service (`diabetes_risk_api/`) | [ML_MODEL_SETUP.md](ML_MODEL_SETUP.md) |
| Putting SUSTHITI on a real server with HTTPS | [DEPLOY.md](DEPLOY.md) |
| Running the test suites, what's covered | [TESTING.md](TESTING.md) |
| Security model and known gaps | [SECURITY.md](SECURITY.md) |

## Secrets, once more

Never commit `.env`, a real `GEMINI_API_KEY`, or `JWT_SECRET`. `.gitignore` already excludes
`.env`, `.env.*` (keeping only `.env.example` files), `*.db`, and `backend/storage/`. Every
`.env.example` in this repo contains placeholders only — `GEMINI_API_KEY=` is deliberately
blank, and `JWT_SECRET=change-me` is deliberately a value production refuses to start with.

## Continuous integration

There is no CI pipeline in this repo yet, and none has been added as part of this work — a
GitHub Actions workflow file written here could not be executed or verified without a
GitHub-hosted runner, so it would be documentation pretending to be tested code. If you want to
add one, this shape matches the two test suites described in [TESTING.md](TESTING.md) and is a
reasonable starting point to adapt and verify yourself in a real run:

```yaml
# .github/workflows/ci.yml  (untested here — verify on your first real push)
name: CI
on: [push, pull_request]
jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install -r backend/requirements.txt -r backend/requirements-dev.txt
      - run: cd backend && python -m pytest
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: "3.47.5" }
      - run: cd app && flutter pub get
      - run: cd app && flutter analyze
      - run: cd app && flutter test
```

Ubuntu runners don't carry Windows's Smart App Control restriction (see
[TESTING.md](TESTING.md)'s note on that), so both suites should run cleanly there even though
`flutter test` cannot run in some local Windows environments.
