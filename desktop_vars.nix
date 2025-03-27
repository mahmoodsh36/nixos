{ pkgs, pinned-pkgs, ... }:

{
  desktop_python = (pinned-pkgs.python3.withPackages (ps: with ps; [
    matplotlib flask requests numpy sympy
    beautifulsoup4 seaborn pillow dash rich
    python-lsp-server

    # would this help for ~/work/widgets?
    pygobject3 pydbus

    # machine learning
    (if (import ./per_machine_vars.nix {}).enable_nvidia
     then torchWithCuda
     else torch)
    (transformers.overrideAttrs(attrs: {
      src = pkgs.fetchFromGitHub {
        owner = "huggingface";
        repo = "transformers";
        rev = "5b08db884443fe9446138dd835cb98b0b4ba5c54";
        sha256 = "SNzO9UojH2RIdQBWyhhp0fC7NLV/NGwQULIX3fUi8Rs=";
      };
    }))
    datasets

    # for system
    evdev pyzmq python-magic
  ]));
  desktop_julia = (pinned-pkgs.julia.withPackages.override({
    precompile = true;
    # extraLibs = [
    #   pkgs.stdenv.cc.cc.lib
    #   pkgs.libGL
    #   pkgs.glib
    #   pkgs.zlib
    # ];
    # # cheating so it can compile
    # makeWrapperArgs = [
    #   "--set DISPLAY ':0'"
    #   "--unset WAYLAND_DISPLAY"
    # ];
  }) ([
    "OhMyREPL" "Symbolics" "SymbolicUtils"

    "Images"
    "LanguageServer"

    # math
    "Graphs" "MetaGraphs" "MetaGraphsNext"

    # data processing
    "JSON" "CSV" "DataFrames"

    # graphics
    "Plots" "GraphRecipes" "TikzPictures" "TikzGraphs" "NetworkLayout" "LayeredLayouts"
    "Makie" "GraphMakie" "CairoMakie" #"GLMakie"
    "GraphPlot" "Compose"
    # "SGtSNEpi" "Karnak"

    # "LogicCircuits" # causes compilation error :(
  ]));
}