FROM jupyter/pyspark-notebook:latest

USER root

# Basic system deps for PyMuPDF and friends
RUN apt-get update && \
    apt-get install -y gcc build-essential libgl1-mesa-glx && \
    rm -rf /var/lib/apt/lists/*

# Python deps for Qwen2.5-VL, vision utilities, and Pydantic
RUN pip install --no-cache-dir \
    "torch" \
    "transformers>=4.44.0" \
    "qwen-vl-utils" \
    "pymupdf" \
    "qwen_vl_utils" \
    "pydantic>=1.10"

# Optional: set a default working directory
WORKDIR /home/jovyan/work

# Expose Jupyter port (already done in base image, but for clarity)
EXPOSE 8888

USER $NB_UID
