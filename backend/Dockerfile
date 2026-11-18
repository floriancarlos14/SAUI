# GPU-enabled SAUI singing voice conversion runtime.
# Build on a host with NVIDIA Container Toolkit and an NVIDIA GPU.
FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    SEED_VC_DIR=/opt/seed-vc \
    PYTHON_EXECUTABLE=python3.10

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3.10 python3.10-venv python3-pip git ffmpeg libsndfile1 \
      build-essential && \
    rm -rf /var/lib/apt/lists/* && \
    ln -sf /usr/bin/python3.10 /usr/local/bin/python

WORKDIR /srv/saui

# Install the API dependencies.
COPY requirements.txt ./requirements-api.txt
RUN python -m pip install --upgrade pip setuptools wheel && \
    python -m pip install -r requirements-api.txt

# Pin a CUDA-compatible PyTorch build, then install the Seed-VC dependencies
# without allowing its upstream requirements to replace the CUDA wheels.
RUN python -m pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
      --index-url https://download.pytorch.org/whl/cu121 && \
    git clone --depth 1 https://github.com/Plachtaa/seed-vc.git "${SEED_VC_DIR}" && \
    grep -Ev '^(torch|torchvision|torchaudio)([[:space:]<=>]|$)|^gradio([[:space:]<=>]|$)|^FreeSimpleGUI([[:space:]<=>]|$)|^sounddevice([[:space:]<=>]|$)' \
      "${SEED_VC_DIR}/requirements.txt" > /tmp/seed-vc-requirements.txt && \
    python -m pip install -r /tmp/seed-vc-requirements.txt

COPY app ./app

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
