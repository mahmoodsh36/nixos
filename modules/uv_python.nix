{ pkgs, python, pyproject-nix, uv2nix, pyproject-build-systems, workspaceRoot, envName ? "venv", cudaSupport ? true, ... }:

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
  # Common overrides that apply regardless of CUDA support
  commonOverrides = final: prev: {
    # onnxruntime - use nixpkgs version as fallback when uv2nix can't resolve it
    # This package sometimes fails to resolve in uv2nix even when wheels exist
    # We use `or` to provide nixpkgs version only if uv2nix fails to resolve it
    onnxruntime =
      if prev ? onnxruntime
      then prev.onnxruntime
      else python.pkgs.onnxruntime;

    # pytesseract - needs setuptools as build dependency
    pytesseract = prev.pytesseract.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; };
    });

    # https://github.com/jpetrucciani/nix/blob/d288481be9ee6b2060df4fc58fe2b321b2fd46e2/mods/py_madness.nix#L292C1-L296C16
    soundfile = prev.soundfile.overrideAttrs (_: {
      postInstall = ''
        substituteInPlace $out/lib/python*/site-packages/soundfile.py --replace "_find_library('sndfile')" "'${pkgs.libsndfile.out}/lib/libsndfile${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}'"
      '';
    });

    rouge-score = prev.rouge-score.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; };
    });
    oumi = prev.oumi.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; };
    });
    sqlitedict = prev.sqlitedict.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; };
    });
    word2number = prev.word2number.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; };
    });
    # opencv-python has complex build requirements - use nixpkgs version
    opencv-python = prev.opencv-python or python.pkgs.opencv4;
    # scipy has complex build requirements - prefer wheel or use nixpkgs version as fallback
    scipy = prev.scipy or python.pkgs.scipy;
    # scikit-image also has complex build requirements - use nixpkgs version
    scikit-image = prev.scikit-image or python.pkgs.scikit-image;
    torchdata = prev.torchdata.overrideAttrs (old: {
      buildInputs = with pkgs; [
        curl
        openssl
      ];
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

  # CUDA-specific overrides
  cudaOverrides = final: prev: {
    nvidia-cusolver-cu12 = prev.nvidia-cusolver-cu12.overrideAttrs (_: {
      buildInputs = [ pkgs.cudatoolkit pkgs.cudaPackages.libnvjitlink ];
    });
    nvidia-cusparse-cu12 = prev.nvidia-cusparse-cu12.overrideAttrs (_: {
      buildInputs = [ pkgs.cudaPackages.libnvjitlink ];
    });
    nvidia-cufile-cu12 = prev.nvidia-cufile-cu12.overrideAttrs (_: {
      autoPatchelfIgnoreMissingDeps = [
        "libmlx5.so.1"
        "librdmacm.so.1"
        "libibverbs.so.1"
      ];
    });
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
    flash-attn = prev.flash-attn.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; torch = [ ]; psutil = []; };
      postFixup = ''
        addAutoPatchelfSearchPath "${final.torch}"
      '';
      preConfigure = ''
        export CUDA_HOME="${pkgs.cudaPackages.cudatoolkit}"
      '';
    });
    torchao = prev.torchao.overrideAttrs (old: cudaPatch old // {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; };
    });
  };

  # Combine overrides based on cudaSupport flag
  pyprojectOverrides =
    if cudaSupport
    then pkgs.lib.composeManyExtensions [ commonOverrides cudaOverrides ]
    else commonOverrides;

  workspace = uv2nix.lib.workspace.loadWorkspace { inherit workspaceRoot; };
  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages {
      inherit python;
    }).overrideScope
      (
        pkgs.lib.composeManyExtensions [
          pyproject-build-systems.overlays.default
          (workspace.mkPyprojectOverlay {
            # Prefer wheels to avoid build dependency issues
            sourcePreference = "wheel";
          })
          pyprojectOverrides
        ]
      );
  venv = (pythonSet.mkVirtualEnv envName workspace.deps.default).overrideAttrs(old: {
    venvIgnoreCollisions = [ "*bin/fastapi" ];
  });
in
venv