# for the CUDA compiler tools (NVCC).
FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

WORKDIR /app

# prevent any interactive prompts during the build
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y python3-pip git

# https://github.com/ultralytics/ultralytics/issues/1270
RUN apt-get install -y libgl1-mesa-glx libgl1-mesa-dev libglib2.0-0

RUN pip install --upgrade pip setuptools wheel packaging

RUN pip install torch==2.1.2 --index-url https://download.pytorch.org/whl/cu121

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

CMD ["python3"]