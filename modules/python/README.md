# Python Environment Module

This module provides a reusable way to create Python environments using `uv2nix`.

## Module Location

- `modules/python/environment.nix` - Main environment builder

## Usage

### 1. Create a Python Environment Directory

```bash
mkdir -p python-envs/myenv
cd python-envs/myenv
```

### 2. Create a `pyproject.toml`

```toml
[project]
name = "myenv"
version = "0.1.0"
requires-python = "==3.12.*"
dependencies = [
    "requests>=2.31.0",
    # Add your dependencies here
]
```

### 3. Generate lockfile

```bash
uv lock --python python3.12
```

### 4. Add to `flake.nix`

In your `devShells`:

```nix
myenv = let
  pythonEnv = mkPythonEnv {
    inherit system;
    workspaceRoot = ./python-envs/myenv;
    envName = "myenv-venv";
    cudaSupport = false;  # Set to true for CUDA support on Linux
  };
in sysPkgs.mkShell {
  packages = [ pythonEnv ];
};
```

### 5. Use the environment

```bash
nix develop .#myenv
```

## Parameters

- `system` - Target system (e.g., "x86_64-linux")
- `workspaceRoot` - Path to directory containing `pyproject.toml` and `uv.lock`
- `envName` - Name for the virtual environment
- `cudaSupport` - Whether to enable CUDA support (default: `false`, only works on Linux)

## Examples

See `python-envs/tesseract/` for a working example with pytesseract.

## Known Limitations

- Some packages like `onnxruntime` may fail to resolve with uv2nix
- CUDA support is only available on Linux systems
- Packages requiring build dependencies may need overrides in `environment.nix`
