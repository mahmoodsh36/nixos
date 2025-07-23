{ pkgs, python, pyproject-nix, uv2nix, pyproject-build-systems, ... }:

let
  cudaPatch = old: {
    nativeBuildInputs =
      (old.nativeBuildInputs or [ ])
      ++ (with pkgs; [
        autoAddDriverRunpath
        cudaPackages.cuda_nvcc
      ]);
    buildInputs =
      (old.buildInputs or [ ]) ++ (with pkgs; [
        libtorch-bin
        (lib.getOutput "cxxdev" python.pkgs.torchWithCuda)
        ffmpeg.dev
      ]) ++ (with pkgs.cudaPackages; [
        cuda_cccl
        cuda_cudart
        cuda_cupti
        cuda_nvcc
        cuda_nvml_dev
        cuda_nvrtc
        cuda_nvtx
        cudnn
        libcublas
        libcufft
        libcurand
        libcusolver
        libcusparse
        cusparselt
        libcufile
        nccl
      ]);
    autoPatchelfIgnoreMissingDeps = [
      "libtorch_cuda.so"
      "libc10_cuda.so"
    ];
  };
  pyprojectOverrides = final: prev: {
    english-words = prev.english-words.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ final.resolveBuildSystem { setuptools = [ ]; };
    });
    html2text = prev.html2text.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ final.resolveBuildSystem { setuptools = [ ]; };
    });
    quantile-python = prev.quantile-python.overrideAttrs (old: { nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; }; });

    # cuda support
    torch = prev.torch.overrideAttrs cudaPatch;
    nvidia-cusolver-cu12 = prev.nvidia-cusolver-cu12.overrideAttrs cudaPatch;
    nvidia-cusparse-cu12 = prev.nvidia-cusparse-cu12.overrideAttrs cudaPatch;
    nvidia-cufile-cu12 = prev.nvidia-cufile-cu12.overrideAttrs cudaPatch;
    torchaudio = prev.torchaudio.overrideAttrs cudaPatch;
    torchvision = prev.torchvision.overrideAttrs cudaPatch;
    cupy-cuda12x = prev.cupy-cuda12x.overrideAttrs cudaPatch;

    xformers = prev.xformers.overrideAttrs (old: cudaPatch old // {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; torch = [ ]; };
      autoPatchelfIgnoreMissingDeps = [
        "libtorch_cuda.so"
        "libc10_cuda.so"
      ];
    });
    vllm = prev.vllm.overrideAttrs (old: cudaPatch old // {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; torch = [ ]; };
      # vllm's setup.py specifically looks for this environment variable.
      preConfigure = ''
        export CUDA_HOME="${pkgs.cudaPackages.cudatoolkit}"
      '';
    });
    numba = prev.numba.overrideAttrs (old: {
      buildInputs = with pkgs; [
        gomp
      ];
      autoPatchelfIgnoreMissingDeps = [
        "libtbb.so.12"
      ];
    });
  };

  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages {
      inherit python;
    }).overrideScope
      (
        pkgs.lib.composeManyExtensions [
          pyproject-build-systems.overlays.default
          (workspace.mkPyprojectOverlay {
            sourcePreference = "wheel";
          })
          pyprojectOverrides
        ]
      );
  venv = pythonSet.mkVirtualEnv "venv" workspace.deps.default;
in
venv