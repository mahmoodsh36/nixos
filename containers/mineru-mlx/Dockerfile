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
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install basic tools
RUN pip install --upgrade pip setuptools wheel packaging

# Install PyTorch (CPU version for ARM64)
RUN pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Copy and install requirements
COPY requirements-mlx.txt .
RUN pip install --no-cache-dir -r requirements-mlx.txt

CMD ["python3"]
