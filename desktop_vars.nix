{ inputs, pkgs, config, pkgs-pinned, ... }:

let
  python-pkgs = pkgs-pinned;
  # python-pkgs = pkgs;
in
{
  desktop_python = (python-pkgs.python3.withPackages (ps: with ps; [
    # essentials
    requests beautifulsoup4
    ipython
    matplotlib numpy sympy networkx pydot
    seaborn pillow dash rich pandas graphviz
    python-lsp-server
    flask

    # for system/scripts etc
    evdev python-magic
    pdf2image
    # pyzmq

    # ml/ai stuff
    torch
    torchvision torchaudio
    accelerate
    datasets
    transformers
    sentence-transformers # for embeddings
    # (transformers.overrideAttrs (finalAttrs: prevAttrs: {
    #   src = pkgs.fetchFromGitHub {
    #     owner = "huggingface";
    #     repo = "transformers";
    #     rev = "38f9c5b15b71243a9f4befee6f20b0fd55a9ba30";
    #     sha256 = "1fl2ac372nykb4vy0cyg490p4jn098xbhibm1jlpz574ylppscy3";
    #   };
    # }))
    diffusers
    mcp
    bitsandbytes
    huggingface-hub hf-xet # latter is needed(preferred) for former
    qdrant-client

    # more?
    gguf
    fschat
    smolagents
    # vllm
    ray
    # tensorrt
    # llama-index-cli llama-index
    # llama-parse

    # langchain langgraph langgraph-cli langsmith # langflow

    # mlflow chromadb
    # llm-gguf llm

    # for hosting?
    # uvicorn fastapi pydantic

    # timm einops tiktoken # some models require these
    # moviepy av librosa # for omni-qwen

    # docling-parse docling docling-core # paddleocr
  ] ++ pkgs.lib.optionals config.machine.enable_nvidia [
  ]));
  desktop_julia = (pkgs-pinned.julia.withPackages.override({
    precompile = false;
    # extralibs = [
    #   pkgs.stdenv.cc.cc.lib
    #   pkgs.libgl
    #   pkgs.glib
    #   pkgs.zlib
    # ];
    # # cheating so it can compile, but doesnt work?
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

    "LogicCircuits" # causes compilation error :(
  ]));
}