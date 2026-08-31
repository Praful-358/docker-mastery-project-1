# =========================================================
# PHASE 3 - ADVANCED
# Multi-stage, Alpine-based, non-root, with a HEALTHCHECK.
# Designed to be built, cached, scanned, tagged, and pushed
# to AWS ECR by the CI/CD pipeline.
# =========================================================

# ---------- Stage 1: Builder ----------
FROM python:3.12-alpine AS builder

WORKDIR /app

# Build-time dependencies needed to compile Python wheels
RUN apk add --no-cache \
    gcc \
    musl-dev \
    libffi-dev

COPY requirements.txt .

RUN pip install --no-cache-dir --user -r requirements.txt


# ---------- Stage 2: Runtime ----------
FROM python:3.12-alpine

WORKDIR /app

# Upgrade Alpine packages to patched versions
RUN apk upgrade --no-cache

# Create a dedicated, unprivileged user
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup

# Copy only installed Python packages
COPY --from=builder /root/.local /home/appuser/.local

# Copy application code
COPY app/ ./app

ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1

# Run as non-root user
USER appuser

EXPOSE 8000

# Container health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
