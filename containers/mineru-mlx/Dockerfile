# Dockerfile for mineru with MLX support (Apple Silicon)
FROM python:3.10-slim

WORKDIR /app

# Prevent any interactive prompts during the build
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && \
    apt-get install -y \
    git \
    build-essential \
    libgl1-mesa-glx \
    libgl1-mesa-dev \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install basic tools
RUN pip install --upgrade pip setuptools wheel packaging

# Install MLX and related packages for Apple Silicon
RUN pip install mlx mlx-lm

# Install PyTorch (CPU version since we're using MLX for acceleration)
RUN pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Copy and install requirements
COPY requirements-mlx.txt .
RUN pip install --no-cache-dir -r requirements-mlx.txt

CMD ["python3"]
