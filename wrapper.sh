#!/bin/sh
# Wrapper for kokoro-fastapi — invoked by the systemd service.

# Ensure correct PYTHONPATH so uvicorn can find api.src.main and internal modules
export PYTHONPATH="@out@/share/kokoro-fastapi/api/src:@out@/share/kokoro-fastapi/api:@out@/share/kokoro-fastapi"

exec @python@/bin/python -m uvicorn api.src.main:app \
  --host "${HOST:-0.0.0.0}" \
  --port "${PORT:-8880}" \
  --log-level "${LOG_LEVEL:-info}"
