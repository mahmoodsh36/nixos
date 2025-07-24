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
        ffmpeg_6-full.lib
        sox
      ]) ++ (with pkgs.cudaPackages; [
        cuda_cccl
        cuda_cudart
        cuda_cupti
        cuda_nvcc
        cuda_nvml_dev
        cuda_nvrtc
        cuda_nvtx
        cudnn
        cutensor
        libcublas
        libcufft
        libcurand
        libcusolver
        libcusparse
        cusparselt
        libcufile
        nccl
        cudatoolkit
      ]);
    autoPatchelfIgnoreMissingDeps = [
      "libtorch_cuda.so"
      "libc10_cuda.so"
    ];
  };
  pyprojectOverrides = final: prev: {
    # cuda support
    # torch = prev.torch.overrideAttrs cudaPatch;
    nvidia-cusolver-cu12 = prev.nvidia-cusolver-cu12.overrideAttrs cudaPatch;
    nvidia-cusparse-cu12 = prev.nvidia-cusparse-cu12.overrideAttrs cudaPatch;
    nvidia-cufile-cu12 = prev.nvidia-cufile-cu12.overrideAttrs cudaPatch;
    # torchvision = prev.torchvision.overrideAttrs cudaPatch;
    # cupy-cuda12x = prev.cupy-cuda12x.overrideAttrs cudaPatch;
    triton = prev.triton.overrideAttrs (_: {
      postInstall = ''
        sed -i -E 's#minor == 6#minor >= 6#g' $out/${python.sitePackages}/triton/backends/nvidia/compiler.py
      '';
    });
    bitsandbytes = prev.bitsandbytes.overrideAttrs (_: {
      buildInputs = with pkgs.cudaPackages; [
        cuda_cudart
        libcublas
        libcusparse
      ];
      postFixup = ''
        addAutoPatchelfSearchPath "${final.nvidia-cusparselt-cu12}"
      '';
      autoPatchelfIgnoreMissingDeps = [
        "libcudart.so.11.0"
        "libcublas.so.11"
        "libcublasLt.so.11"
        "libcusparse.so.11"
      ];
    });

    cupy-cuda12x = prev.cupy-cuda12x.overrideAttrs (old: {
      buildInputs = with pkgs.cudaPackages; [
        cuda_nvrtc
        cudnn_8_9
        cutensor
        libcufft
        libcurand
        libcusolver
        libcusparse
        nccl
      ];
      postFixup = ''
        addAutoPatchelfSearchPath "${final.nvidia-cusparselt-cu12}"
      '';
    });
    torch =
      let
        baseInputs = (python.pkgs.torch.override { cudaSupport = true; }).buildInputs;
      in
        prev.torch.overrideAttrs (_: {
          buildInputs = baseInputs ++ (with pkgs.cudaPackages; [ libcufile ]);
          postFixup = ''
            addAutoPatchelfSearchPath "${final.nvidia-cusparselt-cu12}"
          '';
        });

    # torchaudio = prev.torchaudio.overrideAttrs (old: cudaPatch old // {
    #   nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; torch = [ ]; };
    #   autoPatchelfIgnoreMissingDeps = [
    #     "libavfilter.so.7"
    #     "libavutil.so.56"
    #     "libavcodec.so.58"
    #     "libavformat.so.58"
    #     "libavutil.so.58"
    #     "libavcodec.so.60"
    #     "libavformat.so.60"
    #     "libavfilter.so.9"
    #     "libavutil.so.57"
    #     "libavcodec.so.59"
    #     "libavutil.so.57"
    #     "libavcodec.so.59"
    #     "libavdevice.so.58"
    #     "libavformat.so.59"
    #     "libavdevice.so.59"
    #     "libavfilter.so.8"
    #   ];
    # });
    torchaudio =
    let
      FFMPEG_ROOT = pkgs.symlinkJoin {
        name = "ffmpeg";
        paths = with pkgs; [
          ffmpeg_6-full.bin
          ffmpeg_6-full.dev
          ffmpeg_6-full.lib
        ];
      };
    in
    prev.torchaudio.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.sox ];
      inherit FFMPEG_ROOT;
      autoPatchelfIgnoreMissingDeps = true;
      postFixup = ''
        addAutoPatchelfSearchPath "${final.torch}/${python.sitePackages}/torch/lib"
      '';
    });
    torchvision = prev.torchvision.overrideAttrs (_: {
      postFixup = ''
        addAutoPatchelfSearchPath "${final.torch}/${python.sitePackages}/torch/lib"
      '';
    });

    # xformers = prev.xformers.overrideAttrs (old: cudaPatch old // {
    #   nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; torch = [ ]; };
    #   autoPatchelfIgnoreMissingDeps = [
    #     "libtorch_cuda.so"
    #     "libc10_cuda.so"
    #   ];
    # });
    # vllm = prev.vllm.overrideAttrs (old: cudaPatch old // {
    #   nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; torch = [ ]; };
    #   # vllm's setup.py specifically looks for this environment variable.
    #   preConfigure = ''
    #     export CUDA_HOME="${pkgs.cudaPackages.cudatoolkit}"
    #   '';
    # });
    vllm = prev.vllm.overrideAttrs (_: {
      postFixup = ''
        addAutoPatchelfSearchPath "${final.torch}"
      '';
    });
    xformers = prev.xformers.overrideAttrs (_: {
      postFixup = ''
        addAutoPatchelfSearchPath "${final.torch}"
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
  venv = (pythonSet.mkVirtualEnv "venv" workspace.deps.default).overrideAttrs(old: {
    venvIgnoreCollisions = [ "*bin/fastapi" ];
  });
in
venv