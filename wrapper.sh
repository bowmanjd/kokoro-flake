#!/@python@/bin/python
"""Wrapper for kokoro-fastapi — invoked by the systemd service."""

import os
import sys

# Ensure correct PYTHONPATH so uvicorn can find api.src.main and internal modules
out = "@out@"
paths = [
    f"{out}/share/kokoro-fastapi/api/src",
    f"{out}/share/kokoro-fastapi/api",
    f"{out}/share/kokoro-fastapi",
]
sys.path[:0] = paths
os.environ["PYTHONPATH"] = ":".join(paths) + ":" + os.environ.get("PYTHONPATH", "")

import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "api.src.main:app",
        host=os.environ.get("HOST", "0.0.0.0"),
        port=int(os.environ.get("PORT", "8880")),
        log_level=os.environ.get("LOG_LEVEL", "info"),
    )
