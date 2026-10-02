"""Future diabetes risk (SUSTHITI Diabetes Risk API v4).

snapshot (health_data) -> features.build_features -> client (API v4 /predict) -> stored
DiabetesRiskAssessment, orchestrated by coordinator. Only features.py maps SUSTHITI's health
data to the model's 30 input fields.
"""
