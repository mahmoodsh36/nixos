{ lib, inputs, pkgs, config, config', pkgs-pinned, ... }:

let
  pythonStartupScript = pkgs.writers.writePython3 "startup.py" {
    flakeIgnore = [ "F403" "E261" ];
  } ''
    packages_to_load = {
        "pathlib": "from pathlib import Path",
        "os": "import os",
        "sys": "import sys",
        "math": "from math import *",
    }

    for name, statement in packages_to_load.items():
        try:
            exec(statement, globals())
            print(f"loaded: {name}")
        except ModuleNotFoundError:
            print(f"skip: {name} (not found)")
        except Exception as e:
            print(f"error loading {name}: {e}")
  '';

  main-python = (pkgs.python3.withPackages (ps: with ps; [
    requests beautifulsoup4 dash ipython
    matplotlib numpy
    pillow rich
  ]));
in
{
  config = lib.mkIf (config'.machine.is_desktop && !config'.machine.low_resources) {
    home.packages = [
      (pkgs.writeShellScriptBin "python" ''
        exec ${main-python}/bin/python "$@"
      '')
      (pkgs.writeShellScriptBin "python3" ''
        exec ${main-python}/bin/python "$@"
      '')
      (pkgs.writeShellScriptBin "ipython" ''
        exec ${main-python}/bin/ipython --no-confirm-exit "$@"
      '')
    ];

    home.sessionVariables = {
      # https://docs.python.org/3/using/cmdline.html#envvar-PYTHONSTARTUP
      PYTHONSTARTUP = "${pythonStartupScript}";
      PYTHON_COLORS = "1";
      PYTHONUTF8 = "1";
      # PYTHON_HISTORY = "${config.xdg.cacheHome}/python/python_history";
    };
  };
}