from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

SAMPLE = {
    "Age": 45, "Gender": "Male", "Polyuria": "Yes", "Polydipsia": "Yes",
    "sudden weight loss": "No", "weakness": "Yes", "Polyphagia": "Yes",
    "Genital thrush": "No", "visual blurring": "Yes", "Itching": "No",
    "Irritability": "No", "delayed healing": "Yes", "partial paresis": "No",
    "muscle stiffness": "No", "Alopecia": "No", "Obesity": "Yes"
}

def test_health():
    r = client.get('/health')
    assert r.status_code == 200
    assert r.json()['model_loaded'] is True

def test_prediction():
    r = client.post('/predict', json=SAMPLE)
    assert r.status_code == 200
    body = r.json()
    assert body['prediction'] in ['Positive', 'Negative']
    assert 0 <= body['classification_probability'] <= 1

def test_rejects_extra_field():
    bad = dict(SAMPLE, unexpected='x')
    assert client.post('/predict', json=bad).status_code == 422


# ---------- SUSTHITI additions ----------

ALL_NO = {k: ("No" if v == "Yes" else v) for k, v in SAMPLE.items()}


def test_health_reports_model_identity():
    body = client.get('/health').json()
    assert body['model_name'].startswith('SVM RBF')
    assert body['model_version'].startswith('sha256:') and len(body['model_version']) == len('sha256:') + 12


def test_model_info_exposes_metadata():
    body = client.get('/model-info').json()
    assert body['feature_names'] == list(SAMPLE)
    assert body['target_mapping'] == {'Negative': 0, 'Positive': 1}
    assert body['dataset_info']['age_min'] == 16 and body['dataset_info']['age_max'] == 90
    assert 'not a' in body['limitation']
    assert body['model_version'] == client.get('/health').json()['model_version']


def test_prediction_shape_and_wording():
    positive = client.post('/predict', json=SAMPLE).json()
    negative = client.post('/predict', json=ALL_NO).json()
    assert positive['prediction'] == 'Positive' and positive['interpretation'] == 'Diabetes-related pattern detected by the model'
    assert negative['prediction'] == 'Negative' and negative['interpretation'] == 'No diabetes-related pattern detected by the model'
    # classification_probability is the model's probability for the Positive class.
    assert negative['classification_probability'] < 0.5 < positive['classification_probability']
    for body in (positive, negative):
        assert set(body) == {'prediction', 'classification_probability', 'interpretation', 'model_name', 'model_version', 'disclaimer'}
        assert 'not a medical diagnosis' in body['disclaimer']


def test_prediction_is_deterministic():
    assert client.post('/predict', json=SAMPLE).json() == client.post('/predict', json=SAMPLE).json()


def test_age_boundaries():
    assert client.post('/predict', json=dict(SAMPLE, Age=16)).status_code == 200
    assert client.post('/predict', json=dict(SAMPLE, Age=90)).status_code == 200
    assert client.post('/predict', json=dict(SAMPLE, Age=15)).status_code == 422
    assert client.post('/predict', json=dict(SAMPLE, Age=91)).status_code == 422
    assert client.post('/predict', json=dict(SAMPLE, Age=45.5)).status_code == 422
    assert client.post('/predict', json=dict(SAMPLE, Age=-1)).status_code == 422


def test_rejects_invalid_categories():
    assert client.post('/predict', json=dict(SAMPLE, Gender='Other')).status_code == 422
    assert client.post('/predict', json=dict(SAMPLE, Gender='male')).status_code == 422
    assert client.post('/predict', json=dict(SAMPLE, Polyuria='yes')).status_code == 422
    assert client.post('/predict', json=dict(SAMPLE, Obesity=True)).status_code == 422


def test_rejects_missing_fields():
    for key in SAMPLE:
        partial = {k: v for k, v in SAMPLE.items() if k != key}
        assert client.post('/predict', json=partial).status_code == 422, key


def test_inference_failure_does_not_leak_details(monkeypatch):
    import app.main as main

    def boom(_):
        raise ValueError('secret internal detail')

    monkeypatch.setattr(main.model, 'predict', boom)
    r = client.post('/predict', json=SAMPLE)
    assert r.status_code == 500
    assert 'secret' not in r.text and r.json()['detail'] == 'Model inference failed.'


def test_no_cors_by_default():
    r = client.options('/predict', headers={'Origin': 'https://evil.example', 'Access-Control-Request-Method': 'POST'})
    assert 'access-control-allow-origin' not in {k.lower() for k in r.headers}
