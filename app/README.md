# SUSTHITI Flutter app

Patient, doctor and admin app for SUSTHITI. See the repository [README](../README.md) and
[ARCHITECTURE](../ARCHITECTURE.md).

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
flutter analyze && flutter test
```

The app contains no API keys. All AI and model calls go through the backend.
