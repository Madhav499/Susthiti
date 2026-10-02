"""Checks that feature_config.json matches how the notebook encoded the data.

    python verify_model.py path/to/dataset.csv

Runs the supplied model over every dataset row through the same encoding the API uses and
prints the agreement with the dataset's 'class' column. Low agreement (for example below
0.8) means the Yes/No, Gender or class mapping differs from the notebook: fix
model/feature_config.json before using the service.
"""

import sys

import pandas as pd

from predictor import DiabetesPredictor
from schemas import FEATURES


def main(path: str) -> None:
    data = pd.read_csv(path)
    missing = [f for f in FEATURES if f not in data.columns]
    if missing:
        sys.exit(f"Dataset is missing columns: {missing}")
    target = next((c for c in data.columns if c.lower() == "class"), None)
    predictor = DiabetesPredictor()
    predictor.load()
    if not predictor.ready:
        sys.exit(predictor.error)
    agree = 0
    for _, row in data.iterrows():
        features = {f: (int(row[f]) if f == "Age" else str(row[f]).strip()) for f in FEATURES}
        result = predictor.predict(features)
        if target is not None and result.prediction == str(row[target]).strip():
            agree += 1
    print(f"model_version={predictor.version} input_mode={predictor.input_mode} rows={len(data)}")
    if target is not None:
        print(f"agreement_with_dataset_labels={agree / len(data):.3f}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
