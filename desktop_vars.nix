{ pkgs, pinned-pkgs, ... }:

{
  desktop_python = (pinned-pkgs.python3.withPackages (ps: with ps; [
    matplotlib flask requests numpy pandas sympy
    beautifulsoup4 seaborn pillow dash rich networkx
    python-lsp-server

    # would this help for ~/work/widgets?
    pygobject3 pydbus

    # machine learning
    (if (import ./per_machine_vars.nix {}).enable_nvidia
     then torchWithCuda
     else torch)
    transformers
    datasets

    # for system
    evdev pyzmq python-magic
  ]));
  desktop_julia = (pinned-pkgs.julia.withPackages.override({ precompile = true; })([
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