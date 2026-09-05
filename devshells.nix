# heavy ml CLIs as `nix develop` shells instead of system packages, see modules/uv_python.nix.
{ inputs, nixpkgs, system }:

let
  sysPkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  # usage: mkPythonEnv { workspaceRoot = ./python-envs/foo; envName = "foo-venv"; }
  mkPythonEnv = { workspaceRoot, envName
                , extraOverrides ? ({ pkgs, python }: final: prev: { }), extraDeps ? { } }: let
    pinned = import inputs.pkgs-pinned {
      inherit system;
      config.allowUnfree = true;
    };
  in import ./modules/uv_python.nix {
    pkgs = pinned;
    pyproject-nix = inputs.pyproject-nix;
    uv2nix = inputs.uv2nix;
    pyproject-build-systems = inputs.pyproject-build-systems;
    python = pinned.python312;
    inherit workspaceRoot envName extraOverrides extraDeps;
  };
in
{
  # mineru pdf extraction cli. models are fetched on first run into the
  # huggingface cache, MINERU_MODEL_SOURCE picks where from.
  mineru = let
    venv = mkPythonEnv {
      workspaceRoot = ./python-envs/mineru;
      envName = "mineru-venv";
      extraOverrides = import ./packages/mineru.nix;
    };
  in sysPkgs.mkShell {
    packages = [ venv ];
    shellHook = ''
      # keep the config out of ~/mineru.json. mineru wont create missing
      # parent dirs, so it goes directly in ~/.config.
      export MINERU_TOOLS_CONFIG_JSON="''${MINERU_TOOLS_CONFIG_JSON:-''${XDG_CONFIG_HOME:-$HOME/.config}/mineru.json}"
      export MINERU_MODEL_SOURCE="''${MINERU_MODEL_SOURCE:-huggingface}"
    '';
  };

  uv = sysPkgs.mkShell {
    packages = with sysPkgs; [
      python312
      uv
    ];
    env = {
      UV_PYTHON = sysPkgs.python312.interpreter;
      UV_PYTHON_DOWNLOADS = "never";
      UV_NO_SYNC = "1";
    };
  };
}
# vllm + the vllm-metal plugin (built from source) on apple silicon.
# provides the stock `vllm` cli; vllm-metal has no binary of its own,
# it registers itself through vllm's platform_plugins entry point.
// nixpkgs.lib.optionalAttrs (system == "aarch64-darwin") {
  vllm-metal = let
    venv = mkPythonEnv {
      workspaceRoot = ./python-envs/vllm-metal;
      envName = "vllm-metal-venv";
      extraOverrides = import ./packages/vllm-metal.nix {
        src = inputs.vllm-metal-src;
      };
      extraDeps = { vllm-metal = [ ]; };
    };
  in sysPkgs.mkShell {
    packages = [ venv ];
    # we ship no precompiled .metallib shaders, so the loader has to be
    # told to compile them in-process via mlx. see packages/vllm-metal.nix.
    env.VLLM_METAL_BUILD_FROM_SOURCE = "1";
  };
}
