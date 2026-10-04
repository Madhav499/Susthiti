"""Heart disease risk screening (SUSTHITI Heart Risk API, model susthiti-heart-v3).

snapshot (health_data) + manually entered assessment fields -> features.build_features /
merge_manual -> client (/predict) -> stored HeartRiskAssessment, orchestrated by coordinator.
Only features.py maps SUSTHITI's health data (and the manual questionnaire) to the model's
59 input fields. Sibling to services/diabetes_risk -- same shape, independent model and table,
so nothing here can affect diabetes behaviour.

The supplied model is trained on a 20,000-row SYNTHETIC dataset (see heart_risk_api/README_API.md).
Its result is a screening signal, never a diagnosis -- see services/ai/safety.py and
HeartWording-equivalent client-side copy for how that distinction is kept everywhere it's shown.
"""
