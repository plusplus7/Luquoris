FROM python:3.12.11-slim-bookworm AS base
COPY --from=ghcr.io/astral-sh/uv:0.8.6 /uv /usr/local/bin/uv
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg sox libgomp1 ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --uid 10001 --create-home loquiris \
    && mkdir /app /data /models && chown -R 10001:10001 /app /data /models
WORKDIR /app
COPY --chown=10001:10001 pyproject.toml uv.lock ./
COPY --chown=10001:10001 loquiris_server ./loquiris_server
ENV UV_PROJECT_ENVIRONMENT=/app/.venv PYTHONUNBUFFERED=1 LOQUIRIS_DATA_DIR=/data LOQUIRIS_MODEL_DIR=/models
# Optional build-only trust bundle for an administrator-managed TLS proxy.
RUN --mount=type=secret,id=build_ca \
    if [ -f /run/secrets/build_ca ]; then export SSL_CERT_FILE=/run/secrets/build_ca; fi; \
    uv sync --native-tls --no-cache --frozen --no-dev

FROM base AS api
USER 10001:10001
CMD ["/app/.venv/bin/uvicorn", "loquiris_server.api:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]

FROM base AS worker
# CUDA wheels are large; keep slow or bandwidth-limited builds bounded but usable.
ARG UV_HTTP_TIMEOUT=300
ARG UV_CONCURRENT_DOWNLOADS=4
RUN --mount=type=secret,id=build_ca \
    if [ -f /run/secrets/build_ca ]; then export SSL_CERT_FILE=/run/secrets/build_ca; fi; \
    uv sync --native-tls --no-cache --frozen --extra gpu --no-dev
ENV LD_LIBRARY_PATH=/app/.venv/lib/python3.12/site-packages/nvidia/cublas/lib:/app/.venv/lib/python3.12/site-packages/nvidia/cudnn/lib
USER 10001:10001
CMD ["/app/.venv/bin/python", "-m", "loquiris_server.worker"]
