{ pkgs, config, pinned-pkgs, ... }:

let
  ggufrepo = pkgs.fetchFromGitHub {
    owner = "ggerganov";
    repo = "llama.cpp";
    rev = "92bc493917d43b83e592349e138b54c90b1c3ea7";
    sha256 = "03k3rqc2g74h2nb0lx7vg6jw5fdyc9l0dqfi5jlbcn1dhxj1lagk";
  };
in
{
  desktop_python = (pinned-pkgs.python3.withPackages (ps: with ps; [
    matplotlib flask requests numpy sympy networkx pydot
    beautifulsoup4 seaborn pillow dash rich
    python-lsp-server

    # for system?
    evdev python-magic
    # pyzmq
  ] ++ pkgs.lib.optionals config.machine.enable_nvidia [
    # machine learning
    torchWithCuda
    transformers datasets
    (gguf.overrideAttrs {
      src = "${ggufrepo}/gguf-py" ;
      doCheck = false;
      doInstallCheck = false;
      dontCheck = true;
      dontCheckRuntimeDeps=true;
    })
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