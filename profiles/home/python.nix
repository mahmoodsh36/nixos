{ lib, inputs, pkgs, config, config', pkgs-master, ... }:

let
  pythonStartupScript = pkgs.writers.writePython3 "startup.py" {
    # this tells the linter to ignore specific style warnings.
    # F403: allows 'from math import *'
    # E261: allows single space before inline comments
    flakeIgnore = [ "F403" "E261" ];
  } ''
    print("--- python startup ---")

    # list of modules to preload in the interactive session.
    # for each module, we specify the import statement to execute.
    packages_to_load = {
        "rich": "from rich import print, inspect",
        "pathlib": "from pathlib import Path",
        "os": "import os",
        "sys": "import sys",
        "math": "from math import *",  # Wildcard is convenient for a REPL
    }

    for name, statement in packages_to_load.items():
        try:
            exec(statement, globals())
            print(f"✅ Loaded: {name}")
        except ModuleNotFoundError:
            # This is expected if a package isn't in the environment.
            print(f" S-K-I-P : {name} (not found)")
        except Exception as e:
            # Catch other potential import errors.
            print(f"❌ Error loading {name}: {e}")

    print("----------------------")
  '';

  my-python-1 = pkgs.python3;
  # python-pkgs = pkgs;
  my-python = my-python-1.override {
    packageOverrides = self: super: {
      spotdl = super.toPythonModule super.pkgs.spotdl;
    };
  };

  main-python = (my-python.withPackages (ps: with ps; [
    requests beautifulsoup4 dash ipython
    matplotlib numpy sympy networkx pydot
    seaborn pillow rich pandas graphviz
    python-lsp-server flask imageio
    openai regex

    # for system/scripts etc
    musicbrainzngs ytmusicapi tinytag python-magic
    # evdev
    pdf2image
    music-tag
    spotdl
  ] ++ pkgs.lib.optionals config'.machine.enable_nvidia [
    # ml/ai stuff
    torch torchvision torchaudio accelerate
    datasets transformers
    sentence-transformers # for embeddings
    diffusers
    bitsandbytes
    huggingface-hub hf-xet # latter is needed(preferred) for former
    qdrant-client
    # vllm
    timm einops tiktoken # some models require these
  ]));

  # MLX environment for Apple Silicon
  mlx-python = (my-python.withPackages (ps: with ps; [
    mlx mlx-lm mlx-vlm
    numpy
    pillow
    huggingface-hub
    torch
    transformers rich
  ]));

in
{
  config = lib.mkIf config'.machine.is_desktop {
    home.packages = [
      (pkgs.writeShellScriptBin "python" ''
        # may not need LD_* here
        # export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
        exec ${main-python}/bin/python "$@"
      '')
      (pkgs.writeShellScriptBin "python3" ''
        exec ${main-python}/bin/python "$@"
      '')
      (pkgs.writeShellScriptBin "ipython" ''
        exec ${main-python}/bin/ipython --no-confirm-exit "$@"
      '')
    ] ++ lib.optionals config'.machine.is_darwin [
      (pkgs.writeShellScriptBin "mlx-python" ''
        exec ${mlx-python}/bin/python "$@"
      '')
      (pkgs.writeShellScriptBin "mlx-ipython" ''
        exec ${mlx-python}/bin/ipython --no-confirm-exit "$@"
      '')
      # (pkgs.writeShellScriptBin "mps-transformers" ''
      #   exec ${mlx-python}/bin/transformers "$@"
      # '')
    ];

    # Set environment variables for the Python interpreter.
    home.sessionVariables = {
      # https://docs.python.org/3/using/cmdline.html#envvar-PYTHONSTARTUP
      PYTHONSTARTUP = "${pythonStartupScript}";
      # enable colors in the python 3.13+ repl.
      PYTHON_COLORS = "1";
      # use utf-8 for default text encoding.
      PYTHONUTF8 = "1";
      # set a persistent location for the repl history file.
      # PYTHON_HISTORY = "${config.xdg.cacheHome}/python/python_history";
    };

    # PDB (Python Debugger) configuration
    # https://kylekizirian.github.io/ned-batchelders-updated-pdbrc.html
    home.file.".pdbrc".text = ''
      import pdb

      try:
        from rich import print
      except ModuleNotFoundError:
        pass

      try:
        from IPython import print
      except ModuleNotFoundError:
        pass

      # Print a dictionary's keys and values, nicely formatted.
      # Usage: p_ locals()
      alias p_ for k in sorted(%1.keys()): print(f"%2{k.ljust(max(len(s) for s in %1.keys()))} = {%1[k]}")

      # Print the member variables of an object.
      # Usage: pi my_object
      alias pi p_ %1.__dict__ %1.

      # Print the member variables of self.
      alias ps pi self

      # Print the locals.
      alias pl p_ locals() local:

      # Next and list, and step and list.
      alias nl n;;l
      alias sl s;;l

      # Print the current process ID
      alias pid import os; os.getpid()
    '';
  };
}