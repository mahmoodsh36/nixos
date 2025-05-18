{ pkgs, config, pkgs-pinned, pkgs-master, ... }:

let
  # python-pkgs = (if config.machine.name == "mahmooz2"
  #                then pkgs-master
  #                else pkgs-pinned);
  python-pkgs = pkgs-pinned;
in
{
  desktop_python = (python-pkgs.python3.withPackages (ps: with ps; [
    matplotlib flask requests numpy sympy networkx pydot
    beautifulsoup4 seaborn pillow dash rich pandas
    python-lsp-server

    scikit-learn

    # for system?
    evdev python-magic
    # pyzmq

    # ml stuff
    torch
    torchvision
    accelerate
    transformers datasets
    langchain
    diffusers
    # tensorrt
    mcp
    llm-gguf llm
    bitsandbytes gguf
    # llama-index-cli llama-index
    # llama-parse
    huggingface-hub
    mlflow
    chromadb

    timm einops tiktoken # some models require these

    # docling-parse docling docling-core # paddleocr
    pdf2image
  ] ++ pkgs.lib.optionals config.machine.enable_nvidia [
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