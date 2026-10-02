"""Tests use a tiny TEST-ONLY model trained on synthetic rows at test time, only to exercise
loading, encoding and the API contract. It is never saved into ml_service/model/."""

import sys
from pathlib import Path

import joblib
import numpy as np
import pytest
from fastapi.testclient import TestClient
from sklearn.linear_model import LogisticRegression

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from predictor import DEFAULT_CONFIG_PATH, DiabetesPredictor  # noqa: E402
from schemas import FEATURES  # noqa: E402

YES_NO = FEATURES[2:]


def payload(**overrides):
    body = {"Age": 45, "Gender": "Male", **{f: "No" for f in YES_NO}}
    body.update(overrides)
    return body


@pytest.fixture()
def test_model(tmp_path):
    rng = np.random.default_rng(0)
    X = rng.integers(0, 2, size=(200, 16)).astype(float)
    X[:, 0] = rng.integers(20, 80, size=200)
    y = (X[:, 2] + X[:, 3] >= 1).astype(int)  # synthetic rule, TEST ONLY
    import pandas as pd

    model = LogisticRegression(max_iter=500).fit(pd.DataFrame(X, columns=FEATURES), y)
    path = tmp_path / "test_model.joblib"
    joblib.dump(model, path)
    return path


def client_with(model_path):
    import app as app_module

    app_module.predictor = DiabetesPredictor(model_path, DEFAULT_CONFIG_PATH)
    return TestClient(app_module.app)


def test_missing_model_returns_503(tmp_path):
    with client_with(tmp_path / "missing.joblib") as client:
        assert client.get("/health").json()["status"] == "model_not_loaded"
        r = client.post("/predict", json=payload())
        assert r.status_code == 503


def test_prediction_contract(test_model):
    with client_with(test_model) as client:
        r = client.post("/predict", json=payload(Polyuria="Yes", Polydipsia="Yes"))
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["prediction"] == "Positive"
        assert 0.5 <= body["classification_probability"] <= 1
        assert body["model_version"].startswith("v1+")
        assert client.post("/predict", json=payload()).json()["prediction"] == "Negative"


def test_rejects_extra_missing_and_invalid_inputs(test_model):
    with client_with(test_model) as client:
        assert client.post("/predict", json={**payload(), "BMI": 31}).status_code == 422
        body = payload()
        del body["Alopecia"]
        assert client.post("/predict", json=body).status_code == 422
        assert client.post("/predict", json=payload(Gender="Other")).status_code == 422
        assert client.post("/predict", json=payload(Age=0)).status_code == 422
        assert client.post("/predict", json=payload(Itching="yes please")).status_code == 422


def test_encoding_maps_every_feature(test_model):
    predictor = DiabetesPredictor(test_model, DEFAULT_CONFIG_PATH)
    predictor.load()
    frame = predictor.encode(payload(Gender="Female", Obesity="Yes"))
    assert list(frame.columns) == list(FEATURES)
    assert frame.iloc[0]["Gender"] == 0 and frame.iloc[0]["Obesity"] == 1 and frame.iloc[0]["Age"] == 45


def test_refuses_model_with_different_columns(tmp_path):
    import pandas as pd

    model = LogisticRegression().fit(pd.DataFrame({"BMI": [20.0, 35.0], "Glucose": [90.0, 200.0]}), [0, 1])
    path = tmp_path / "other.joblib"
    joblib.dump(model, path)
    predictor = DiabetesPredictor(path, DEFAULT_CONFIG_PATH)
    predictor.load()
    assert not predictor.ready and "different input columns" in predictor.error
