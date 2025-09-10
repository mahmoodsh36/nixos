{ inputs, pkgs, config, pkgs-pinned, ... }:

let
  my-python-pkgs = pkgs-pinned;
  my-python-1 = my-python-pkgs.python3;
  # python-pkgs = pkgs;
  my-python = my-python-1.override {
    packageOverrides = self: super: {
      spotdl = super.toPythonModule super.pkgs.spotdl;
    };
  };
in
{
  desktop_python = (my-python.withPackages (ps: with ps; [
    # essentials
    requests beautifulsoup4
    # dash
    ipython
    matplotlib numpy sympy networkx pydot
    seaborn pillow rich pandas graphviz
    python-lsp-server
    flask
    imageio

    # for system/scripts etc
    musicbrainzngs ytmusicapi tinytag python-magic
    evdev
    pdf2image
    music-tag
    spotdl

    flask
    imageio
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
    # vllm

    langchain langgraph langgraph-cli langsmith langchain-community # langflow
    openai

    timm einops tiktoken # some models require these
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

    # "LogicCircuits" # causes compilation error :(
  ]));
}