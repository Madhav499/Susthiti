# Superseded

This placeholder service is no longer used. It expected the `.joblib` to be a bare model object, but the
supplied artifact is a dictionary (pipeline plus metadata), so it could not load it.

SUSTHITI now uses the supplied API in [`../diabetes_api/`](../diabetes_api/README.md). See
[`../ML_MODEL_SETUP.md`](../ML_MODEL_SETUP.md). This folder can be deleted.
