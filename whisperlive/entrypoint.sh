#!/bin/bash
set -euo pipefail

# Start streamlit in foreground (so the container stays alive)
exec uvicorn whisper:app --host 0.0.0.0 --port 8501 --reload

# Run
# ssh -L 8501:localhost:8501 seshu@192.168.27.13