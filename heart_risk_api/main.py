from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import Any, Dict, Optional
import pandas as pd
import numpy as np
import joblib
import re
from pathlib import Path

BASE = Path(__file__).resolve().parent
BUNDLE = joblib.load(BASE / "model.joblib")
MODEL = BUNDLE["model"]
MODEL.named_steps["model"].set_params(n_jobs=1)
CALIBRATOR = BUNDLE["calibrator"]
THRESHOLD = float(BUNDLE["threshold"])
FEATURES = BUNDLE["features"]
VERSION = BUNDLE.get("model_version", "susthiti-heart-v3")
METRICS = BUNDLE.get("metrics", {})

app = FastAPI(title="Susthiti Heart Disease Risk API", version=VERSION,
              description="Heart-disease risk screening model API for the Susthiti project. Synthetic-data model; not a clinical diagnostic service.")

class PredictionRequest(BaseModel):
    data: Dict[str, Any] = Field(default_factory=dict)

# User-friendly aliases -> training categories
ALIASES = {
    "sex": {"male":"Male","m":"Male","female":"Female","f":"Female"},
    "smoking_status": {"never":"Never","non-smoker":"Never","nonsmoker":"Never","former":"Former","ex-smoker":"Former","current":"Current","current smoker":"Current","frequently":"Current","frequent":"Current"},
    "alcohol_frequency": {"never":"Never","rare":"Rare","occasionally":"Occasional","occasional":"Occasional","sometimes":"Occasional","frequently":"Frequent","frequent":"Frequent"},
    "physical_activity_level": {"low":"Low","moderate":"Moderate","medium":"Moderate","high":"High"},
    "chest_pain_type": {"none":None,"typical angina":"Typical_Angina","typical_angina":"Typical_Angina","atypical angina":"Atypical_Angina","atypical_angina":"Atypical_Angina","non-anginal":"Non_Anginal","non anginal":"Non_Anginal","non_anginal":"Non_Anginal"},
    "resting_ecg": {"normal":"Normal","normal variant":"Normal_Variant","normal_variant":"Normal_Variant","st-t abnormality":"ST_T_Abnormality","st_t_abnormality":"ST_T_Abnormality","abnormal":"ST_T_Abnormality","old infarct pattern":"Old_Infarct_Pattern","old_infarct_pattern":"Old_Infarct_Pattern","lvh":"LVH"},
    "stress_test_result": {"normal":"Negative","negative":"Negative","borderline":"Borderline","abnormal":"Positive","positive":"Positive"},
    "echocardiogram_result": {"normal":"Normal","mild abnormality":"Mild_Abnormality","mild_abnormality":"Mild_Abnormality","significant abnormality":"Significant_Abnormality","significant_abnormality":"Significant_Abnormality","abnormal":"Significant_Abnormality"},
    "diet_quality": {"poor":"Poor","average":"Average","moderate":"Average","modarate":"Average","good":"Good","excellent":"Excellent"},
}
BINARY = {"family_history_heart_disease","previous_heart_disease","previous_heart_attack","hypertension","diabetes","high_cholesterol","kidney_disease","stroke_history","chest_pain","shortness_of_breath","fatigue","dizziness","fainting","sweating","nausea","palpitations","pain_left_arm","pain_jaw_neck","pain_back","ecg_abnormality","exercise_induced_angina","heart_wall_motion_abnormality","previous_cardiac_test_abnormal"}
NUM_RANGES = {
    "age":(0,120),"height_cm":(50,250),"weight_kg":(2,400),"bmi":(5,100),"chest_pain_duration_min":(0,600),
    "resting_heart_rate":(25,250),"systolic_bp":(50,300),"diastolic_bp":(30,200),"oxygen_saturation":(50,100),"respiratory_rate":(5,60),
    "fasting_glucose":(20,800),"random_glucose":(20,1000),"hba1c":(2,25),"total_cholesterol":(50,1000),"ldl":(10,600),"hdl":(5,250),"triglycerides":(20,2000),
    "troponin":(0,100),"hemoglobin":(3,25),"creatinine":(0.1,20),"st_depression":(0,20),"max_heart_rate":(30,260),"exercise_duration_min":(0,300),
    "ejection_fraction":(5,100),"sleep_hours":(0,24),"stress_level":(0,10),"sedentary_hours_per_day":(0,24)
}

def keynorm(s): return re.sub(r"[^a-z0-9]+", "_", str(s).strip().lower()).strip("_")

def normalize(data: Dict[str,Any]):
    # accept common camelCase/space variations
    src={keynorm(k):v for k,v in data.items()}
    # common alternate names
    aliases_keys={"height":"height_cm","weight":"weight_kg","heart_rate":"resting_heart_rate","systolic":"systolic_bp","diastolic":"diastolic_bp","spo2":"oxygen_saturation","oxygen_saturation_percent":"oxygen_saturation","hba_1c":"hba1c","ef":"ejection_fraction"}
    for a,b in aliases_keys.items():
        if a in src and b not in src: src[b]=src[a]
    clean={}
    warnings=[]
    errors=[]
    for f in FEATURES:
        if f not in src or src[f] is None or src[f]=="": continue
        v=src[f]
        if f in ALIASES and isinstance(v,str):
            k=v.strip().lower(); v=ALIASES[f].get(k,v)
        if f in BINARY:
            if isinstance(v,bool): v=int(v)
            elif isinstance(v,(int,float)) and v in (0,1): v=int(v)
            elif isinstance(v,str) and v.strip().lower() in {"yes","true","y","1"}: v=1
            elif isinstance(v,str) and v.strip().lower() in {"no","false","n","0"}: v=0
            else: errors.append(f"{f} must be 0/1 or yes/no") ; continue
        if f in NUM_RANGES:
            try: v=float(v); 
            except Exception: errors.append(f"{f} must be numeric"); continue
            lo,hi=NUM_RANGES[f]
            if not lo <= v <= hi: errors.append(f"{f} must be between {lo} and {hi}"); continue
        clean[f]=v
    # Derive BMI when not supplied
    if "bmi" not in clean and "height_cm" in clean and "weight_kg" in clean:
        h=clean["height_cm"]/100
        if h>0: clean["bmi"]=clean["weight_kg"]/(h*h)
    # Strictly reject fractional binary symptom values rather than silently interpreting them
    return clean, errors, warnings

def calibrated_probability(raw):
    logit=np.log(np.clip(raw,1e-6,1-1e-6)/(1-np.clip(raw,1e-6,1-1e-6)))
    return float(CALIBRATOR.predict_proba(np.array([[logit]]))[:,1][0])

def risk_level(p):
    if p >= 0.70: return "high"
    if p >= 0.40: return "moderate"
    return "low"

@app.get("/health")
def health():
    return {"status":"ok","model_version":VERSION}

@app.get("/model-info")
def model_info():
    return {"model_version":VERSION,"features":FEATURES,"threshold":THRESHOLD,"metrics":METRICS,"note":"Synthetic-data model; not a clinical diagnostic service."}

@app.post("/predict")
def predict(req: PredictionRequest):
    clean, errors, warnings = normalize(req.data)
    if errors: raise HTTPException(status_code=422, detail={"errors":errors})
    row={f:clean.get(f,np.nan) for f in FEATURES}
    frame=pd.DataFrame([row],columns=FEATURES)
    try: raw=float(MODEL.predict_proba(frame)[:,1][0])
    except Exception as e: raise HTTPException(status_code=500, detail=f"Prediction failed: {e}")
    probability=calibrated_probability(raw)
    prediction=int(probability>=THRESHOLD)
    return {"model_version":VERSION,"prediction":prediction,"prediction_label":"Heart disease risk detected" if prediction else "No high heart-disease risk detected","probability":round(probability,4),"probability_percent":round(probability*100,2),"risk_level":risk_level(probability),"decision_threshold":THRESHOLD,"warnings":warnings,"disclaimer":"For Susthiti software/project screening only. This synthetic-data model is not a medical diagnosis."}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app,host="0.0.0.0",port=8000)
