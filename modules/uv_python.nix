{ pkgs, python, pyproject-nix, uv2nix, pyproject-build-systems, workspaceRoot, envName ? "venv"
# composed last, so an env can correct anything the shared overrides above get
# wrong for it (e.g. the hardcoded mlx version). called with the resolved
# pkgs/python so an env-specific package builds against the same ones.
, extraOverrides ? ({ pkgs, python }: final: prev: { })
# extra packages to pull into the venv that the workspace lock does not
# declare, for nix-built packages injected via extraOverrides.
, extraDeps ? { }
, ... }:

let
  commonOverrides = final: prev: {
    # fallback when uv2nix fails to resolve it even though wheels exist
    onnxruntime =
      if prev ? onnxruntime
      then prev.onnxruntime
      else python.pkgs.onnxruntime;

    # https://github.com/jpetrucciani/nix/blob/d288481be9ee6b2060df4fc58fe2b321b2fd46e2/mods/py_madness.nix#L292C1-L296C16
    soundfile = prev.soundfile.overrideAttrs (_: {
      postInstall = ''
        substituteInPlace $out/lib/python*/site-packages/soundfile.py --replace "_find_library('sndfile')" "'${pkgs.libsndfile.out}/lib/libsndfile${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}'"
      '';
    });

    pyarrow = prev.pyarrow.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ])
        ++ final.resolveBuildSystem { setuptools = [ ]; cython = [ ]; numpy = [ ]; }
        ++ [ pkgs.cmake pkgs.pkg-config ];
      buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.arrow-cpp ];
    });
    # complex build, use nixpkgs version
    opencv-python = python.pkgs.opencv4;
    # complex build, prefer wheel with nixpkgs fallback
    scipy = prev.scipy or python.pkgs.scipy;
    mlx = pkgs.stdenv.mkDerivation {
      pname = "mlx";
      version = "0.30.0";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/94/a3/32c4c05d8967591e2a1a1e7e3fc9cece8821f5aea8ac8f3bcfdb203f4722/mlx-0.30.0-cp312-cp312-macosx_14_0_arm64.whl";
        hash = "sha256-EfuuWLHpkq/exnCdXigZMocaAThYKnlM3Mgv+JWihnA=";
      };
      nativeBuildInputs = [ pkgs.unzip ];
      propagatedBuildInputs = [ final.mlx-metal ];
      unpackPhase = "unzip $src";
      installPhase = ''
        mkdir -p $out/lib/python3.12/site-packages
        cp -r mlx* $out/lib/python3.12/site-packages/
      '';
      postFixup = ''
        metalLib="${final.mlx-metal}/lib/python3.12/site-packages/mlx/lib"
        find $out/lib/python3.12/site-packages/mlx -name "*.so" -exec install_name_tool -add_rpath "$metalLib" {} \;
        find $out/lib/python3.12/site-packages/mlx -name "*.so" -exec install_name_tool -change @rpath/libmlx.dylib "$metalLib/libmlx.dylib" {} \;
      '';
    };
    mlx-metal = pkgs.stdenv.mkDerivation {
      pname = "mlx-metal";
      version = "0.30.0";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/64/9f/47ebb6e9b2c33371c6ca3733e70324ed064f49e790ee4e194b713d6d7d84/mlx_metal-0.30.0-py3-none-macosx_14_0_arm64.whl";
        hash = "sha256-9IVDsQ0TvwWRs/mcbrWF3SwuXbN57a5d8PGacoy0F0I=";
      };
      nativeBuildInputs = [ pkgs.unzip ];
      unpackPhase = "unzip $src";
      installPhase = ''
        mkdir -p $out/lib/python3.12/site-packages
        cp -r * $out/lib/python3.12/site-packages/
      '';
    };
    mlx-lm = prev.mlx-lm.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ final.resolveBuildSystem { setuptools = []; };
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

  resolvedExtra = extraOverrides { inherit pkgs python; };

  pyprojectOverrides =
    pkgs.lib.composeManyExtensions [ commonOverrides resolvedExtra ];

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
  venv = pythonSet.mkVirtualEnv envName (workspace.deps.default // extraDeps);
in
venv