{ pkgs, config, pkgs-pinned, pkgs-master, ... }:

let
  python-pkgs = (if config.machine.name == "mahmooz2"
                 then pkgs-master
                 else pkgs-pinned);
in
{
  desktop_python = (python-pkgs.python3.withPackages (ps: with ps; [
    matplotlib flask requests numpy sympy networkx pydot
    beautifulsoup4 seaborn pillow dash rich
    python-lsp-server

    # for system?
    evdev python-magic
    # pyzmq

    # ml stuff
    (if config.machine.enable_nvidia
     then torch
     else torchWithCuda)
    transformers
    datasets
    langchain
  ] ++ pkgs.lib.optionals config.machine.enable_nvidia [
    # machine learning with nvidia
  ]));
  desktop_julia = (pkgs-pinned.julia.withPackages.override({
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