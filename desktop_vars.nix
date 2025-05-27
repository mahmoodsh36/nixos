{ pkgs, config, pkgs-pinned, ... }:

let
  # python-pkgs = (if config.machine.name == "mahmooz2"
  #                then pkgs-master
  #                else pkgs-pinned);
  # python-pkgs = pkgs-pinned;
  python-pkgs = pkgs;
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
    torchvision torchaudio
    accelerate
    # transformers
    datasets
    (transformers.overrideAttrs (finalAttrs: prevAttrs: {
      src = pkgs.fetchFromGitHub {
        owner = "huggingface";
        repo = "transformers";
        rev = "38f9c5b15b71243a9f4befee6f20b0fd55a9ba30";
        sha256 = "1fl2ac372nykb4vy0cyg490p4jn098xbhibm1jlpz574ylppscy3";
      };
    }))
    langchain
    diffusers
    # tensorrt
    mcp
    bitsandbytes gguf
    # llama-index-cli llama-index
    # llama-parse
    huggingface-hub hf-ext # latter is needed(preferred) for former

    mlflow chromadb
    llm-gguf llm

    # for hosting?
    uvicorn fastapi pydantic

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