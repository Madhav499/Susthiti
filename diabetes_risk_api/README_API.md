# SUSTHITI API v4

## Run
```bash
pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

Open `http://127.0.0.1:8000/docs` for Swagger testing.

## Flutter
- Android emulator: `http://10.0.2.2:8000`
- Physical Android phone: use the computer LAN IP, e.g. `http://192.168.1.10:8000`

## Report detection
The API **does not** treat `previous_prediabetes=yes` as proof that a report was supplied.

A report is considered available only if at least one of these fields has a real value:
- `hba1c`
- `fasting_glucose`
- `random_glucose`
- `previous_ogtt_2h`
- `previous_health_report_status`

For `previous_health_report_status`, use only the dataset's report classifications:
- `Normal`
- `Prediabetes`
- `Diabetes`

Do **not** send `Available` as the model's report-status value.

## Risk bands
- 0%–40%: Low
- >40%–65%: Moderate
- >65%: High

## No-report response
The response uses:
```json
"prediction_basis": "symptoms_and_risk_factors_only",
"report_available": false,
"report_fields_present": []
```

## Report response
For example, if only random glucose is extracted from a report:
```json
"report_available": true,
"report_fields_present": ["random_glucose"]
```

## Safety
This is an ML research/screening prototype trained on synthetic data. It is not clinically validated and is not a medical diagnosis.
