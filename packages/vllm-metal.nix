# vllm-metal built from source. the published wheel bundles native artifacts
# that upstream CI produces and gitignores, so we rebuild them here.
#
# we skip the rust extension (vllm_metal._rs), an empty pyo3 stub nothing
# imports, and we don't precompile the .metallib shaders because that needs
# `xcrun metal`, which the sandbox lacks. the venv sets
# VLLM_METAL_BUILD_FROM_SOURCE=1 so MLX compiles them in-process.
#
# that env var also rebuilds the .so when it looks stale, which would fail on a
# read-only store path. it never looks stale: we ship the .sha256 stamp build.py
# wrote over the same sources and mlx/nanobind versions.
{ src }:
{ pkgs, python }:

final: prev:

let
  pyVer = python.pythonVersion;
  sitePackages = "lib/python${pyVer}/site-packages";

  mlxLibDir = "${final.mlx-metal}/${sitePackages}/mlx/lib";

  # mlx-metal is listed explicitly because it ships the headers and
  # libmlx.dylib, and the venv builder resolves from passthru.dependencies, not
  # from build inputs.
  buildPython = final.mkVirtualEnv "vllm-metal-build-env" {
    mlx = [ ];
    mlx-metal = [ ];
    nanobind = [ ];
  };
in
{
  # modules/uv_python.nix hardcodes mlx 0.30.0, but vllm-metal pins 0.32.0
  # exactly: libmlx.dylib carries no SONAME version, so the extension is only
  # ABI-safe against the MLX it was built against.
  mlx = pkgs.stdenv.mkDerivation {
    pname = "mlx";
    version = "0.32.0";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/aa/a6/489176d8a2a06137a299910057cc44dc3fccfb73151f7562fea2b75894d9/mlx-0.32.0-cp312-cp312-macosx_14_0_arm64.whl";
      hash = "sha256-6lpZQ1XInACV6rpBP9OdTKqGQvoTQy37DJNU0UEEZGc=";
    };
    nativeBuildInputs = [ pkgs.unzip ];
    propagatedBuildInputs = [ final.mlx-metal ];
    # or mlx lands in a venv without the libmlx.dylib it links against.
    passthru.dependencies = { mlx-metal = [ ]; };
    unpackPhase = "unzip $src";
    installPhase = ''
      mkdir -p $out/${sitePackages}
      cp -r mlx* $out/${sitePackages}/
    '';
    postFixup = ''
      find $out/${sitePackages}/mlx -name "*.so" \
        -exec install_name_tool -add_rpath "${mlxLibDir}" {} \;
      find $out/${sitePackages}/mlx -name "*.so" \
        -exec install_name_tool -change @rpath/libmlx.dylib "${mlxLibDir}/libmlx.dylib" {} \;
    '';
  };

  mlx-metal = pkgs.stdenv.mkDerivation {
    pname = "mlx-metal";
    version = "0.32.0";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/d6/ef/d74ae99cfe9ddb59fd08abd14f47754c3d199291a93756903fa595b31b8a/mlx_metal-0.32.0-py3-none-macosx_14_0_arm64.whl";
      hash = "sha256-W2SyCsJLDEAfSJ3gHoIJ7cTTchJSAfGTFObznjhTIqo=";
    };
    nativeBuildInputs = [ pkgs.unzip ];
    unpackPhase = "unzip $src";
    installPhase = ''
      # both wheels unpack into mlx/ and share these five byte-identical files.
      # pip lets the second install win, a nix venv calls it a collision, so let
      # mlx provide them.
      rm -f mlx/__main__.py mlx/_reprlib_fix.py mlx/extension.py mlx/py.typed mlx/utils.py

      mkdir -p $out/${sitePackages}
      cp -r * $out/${sitePackages}/
    '';
  };

  # mlx-vlm wants opencv-python, vllm and mistral-common want
  # opencv-python-headless, both 5.0.0.93, and their cv2/ trees collide.
  # collapse onto headless. this also displaces the shared override mapping
  # opencv-python to nixpkgs' opencv4, which is what actually collided.
  opencv-python = final.opencv-python-headless;

  vllm-metal = pkgs.stdenv.mkDerivation {
    pname = "vllm-metal";
    # upstream stamps a per-commit .devN suffix at release time.
    version = "0.3.0";
    inherit src;

    nativeBuildInputs = [ buildPython pkgs.unzip ];
    buildInputs = [ final.mlx final.mlx-metal ];

    # build.py writes the .so and its stamp next to the sources.
    postUnpack = ''chmod -R u+w "$sourceRoot"'';

    buildPhase = ''
      runHook preBuild
      export PYTHONPATH="$PWD''${PYTHONPATH:+:$PYTHONPATH}"
      # build() only, since the module's __main__ also calls build_metallibs().
      python -c 'import logging, vllm_metal.metal.build as b; logging.basicConfig(level=logging.INFO); print(b.build())'
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/${sitePackages}"
      cp -r vllm_metal "$out/${sitePackages}/"

      # vLLM discovers the metal platform only through the entry points below,
      # and silently falls back to CPU without them.
      distinfo="$out/${sitePackages}/vllm_metal-$version.dist-info"
      mkdir -p "$distinfo"

      cat > "$distinfo/METADATA" <<EOF
      Metadata-Version: 2.3
      Name: vllm-metal
      Version: $version
      Summary: vLLM hardware plugin for Apple Silicon
      License: Apache-2.0
      EOF

      cat > "$distinfo/WHEEL" <<EOF
      Wheel-Version: 1.0
      Generator: nix
      Root-Is-Purelib: false
      Tag: py${builtins.replaceStrings [ "." ] [ "" ] pyVer}-none-any
      EOF

      # mirrors [project.entry-points] upstream.
      cat > "$distinfo/entry_points.txt" <<EOF
      [vllm.platform_plugins]
      metal = vllm_metal:register

      [vllm.general_plugins]
      gguf_metal = vllm_metal.gguf.vllm_integration:register
      EOF

      : > "$distinfo/RECORD"
      runHook postInstall
    '';

    # the .so carries no rpath by design. it resolves libmlx by install name
    # against an already-loaded image, which metal/__init__.py guarantees by
    # importing mlx.core first.
    dontFixup = true;

    passthru.dependencies = {
      mlx = [ ];
      mlx-lm = [ ];
      mlx-vlm = [ ];
      transformers = [ ];
      accelerate = [ ];
      safetensors = [ ];
      nanobind = [ ];
      numpy = [ ];
      psutil = [ ];
      llguidance = [ ];
      fastapi = [ ];
      starlette = [ ];
    };

    meta = {
      description = "vLLM hardware plugin for Apple Silicon (MLX/Metal backend)";
      homepage = "https://github.com/vllm-project/vllm-metal";
      license = pkgs.lib.licenses.asl20;
      platforms = [ "aarch64-darwin" ];
    };
  };
}
