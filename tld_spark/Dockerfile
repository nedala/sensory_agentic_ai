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
    "pydantic>=1.10" \
    "torchvision" \
    "accelerate"

# Optional: set a default working directory
WORKDIR /home/jovyan/work

# Expose Jupyter port (already done in base image, but for clarity)
EXPOSE 8888

RUN mkdir -p /etc/jupyter && \
    cat > /etc/jupyter/jupyter_notebook_config.py <<'PYCONF'
c.NotebookApp.token = ''
c.NotebookApp.password = ''
c.NotebookApp.open_browser = False
c.NotebookApp.ip = '0.0.0.0'
# jupyter_server compatibility
c.ServerApp.token = ''
c.ServerApp.password = ''
c.ServerApp.open_browser = False
c.ServerApp.ip = '0.0.0.0'
PYCONF
RUN chmod 644 /etc/jupyter/jupyter_notebook_config.py

RUN pip install --no-cache-dir yapf black isort jupyterlab-code-formatter bitsandbytes
USER $NB_UID
