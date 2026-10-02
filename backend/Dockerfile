# SUSTHITI backend for a server. Deploy with deploy/docker-compose.yml (see DEPLOY.md).
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app ./app

# Records and uploaded reports live on the /data volume, never inside the image.
RUN useradd --create-home --uid 10001 susthiti && mkdir -p /data/storage && chown -R susthiti /data
USER susthiti
ENV SUSTHITI_ENV=production \
    DATABASE_URL=sqlite:////data/susthiti.db \
    STORAGE_DIR=/data/storage
VOLUME ["/data"]

EXPOSE 8000
# One process: the reminder loop and the sign-in rate limiter assume a single instance.
# --proxy-headers: the real visitor address comes from the reverse proxy (Caddy), which is the
# only thing that can reach this port inside the Docker network.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips", "*"]
