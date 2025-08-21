# podman build --memory=30g --cpuset-cpus="0-9" -t mypy .
# podman run -it --gpus all mypy python3

# for the CUDA compiler tools (NVCC).
FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

WORKDIR /app

# prevent any interactive prompts during the build
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y python3-pip git && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip setuptools wheel packaging

RUN pip install torch==2.1.2 --index-url https://download.pytorch.org/whl/cu121

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN VLLM_USE_PRECOMPILED=1 pip install git+https://github.com/FoolPlayer/vllm.git@seed-oss
RUN pip install git+https://github.com/Fazziekey/transformers.git@seed-oss
RUN pip install lmcache

CMD ["python3"]