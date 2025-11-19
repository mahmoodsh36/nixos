# Transformers MPS Environment

This Python environment provides Hugging Face Transformers with serving capabilities, PyTorch with MPS (Metal Performance Shaders) support for macOS, and related dependencies.

## Features

- Transformers with serving dependencies
- PyTorch with MPS support for macOS GPU acceleration
- Torchvision and Torchaudio
- Accelerate for easy multi-device training
- Uvicorn for serving models via web API
- Safetensors for secure model loading
- Optimum for optimized inference

## Usage

To enter the development shell:
```bash
nix develop .#transformers-mps
```

## Model Serving

This environment includes the necessary dependencies to serve transformer models using the Hugging Face transformers serving capabilities. You can use tools like:
- `transformers` pipeline for inference
- `uvicorn` for API serving
- `fastapi` for creating web APIs (available through transformers[serving])

## MPS Support

On macOS systems, this environment will leverage MPS (Metal Performance Shaders) for hardware acceleration when using PyTorch models. The environment is configured with the necessary flags:

- `PYTORCH_ENABLE_MPS_FALLBACK=1` - Enables MPS fallback for unsupported operations
- `TORCH_MPS_DEVICE_ENABLED=1` - Enables MPS device support