#!/bin/bash
set -e
ollama serve &
sleep 5
ollama pull ${MODEL_NAME}