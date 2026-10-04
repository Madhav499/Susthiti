# SUSTHITI Heart Disease Risk API v3 (private: only the SUSTHITI backend calls it).
FROM python:3.12-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY main.py model.joblib ./
RUN useradd --create-home --uid 10003 model
USER model
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
