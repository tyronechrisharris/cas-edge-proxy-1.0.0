FROM python:3.13-slim-bookworm

ARG VERSION=1.0.0
LABEL org.opencontainers.image.title="CAS Edge Proxy" \
      org.opencontainers.image.description="Multi-RPM and IP-camera TCP/UDP proxy for Raspberry Pi, Linux, and Docker Desktop" \
      org.opencontainers.image.version="${VERSION}"

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app
COPY --chown=65534:65534 cas_proxy /app/cas_proxy
COPY --chown=65534:65534 config/config.json /config/config.json

USER 65534:65534

EXPOSE 9090 11601 11602 18001 18443 18554 28001 28443 28554

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["python", "-m", "cas_proxy", "--check", "http://127.0.0.1:9090/healthz"]

ENTRYPOINT ["python", "-m", "cas_proxy"]
CMD ["--config", "/config/config.json"]
