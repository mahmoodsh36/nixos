{ pkgs, pinned-pkgs, ... }:

# let
#   pinned-pkgs = import (builtins.fetchTarball {
#     url = "https://github.com/NixOS/nixpkgs/archive/64e75cd44acf21c7933d61d7721e812eac1b5a0a.tar.gz";
#   }) {};
# in
{
  desktop_python = (pinned-pkgs.python3.withPackages (ps: with ps; [
    matplotlib flask requests panflute numpy jupyter jupyter-core pandas sympy scipy
    beautifulsoup4 seaborn pillow dash mysql-connector
    rich networkx dpkt python-lsp-server opencv4
    # graphviz flask-sqlalchemy flask-cors ariadne graphene
    # python-magic

    # machine learning
    pytorch torchvision
    scikit-learn
    transformers
    diffusers
    spacy gensim nltk
    datasets

    # for homework
    psutil
    pynput
  ]));
  desktop_julia = (pinned-pkgs.julia.withPackages.override({ precompile = false; })([
    # "TruthTables" "LinearSolve"
    # "HTTP" "OhMyREPL" "MLJ"
    # "Luxor" "ReinforcementLearningBase" "DataStructures" "RecipesBase"
    # "Distributions" "Gen" "UnicodePlots" "StaticArrays"
    # "Genie" "WaterLily"
    # "ForwardDiff" "TermInterface" "SymbolicRegression"
    # "Transformers" "Knet" "ModelingToolkit" "StatsPlots" "Zygote"
    # "Flux" "JET" "LoopVectorization" "Weave" "BrainFlow"
    # "CUDA" "Javis" "GalacticOptim" "Dagger" "Interact"
    # "Gadfly" "Turing" "RecipesPipeline"
    # "Flux"
    # "Symbolics" "SymbolicUtils"


    # "OhMyREPL"
    # "Metatheory"
    # "Latexify"
    # "CUDA" "MLJ"

    # "Images"
    # "LanguageServer"

    # math
    "Graphs" "MetaGraphs" "MetaGraphsNext"

    # data processing
    "JSON" "CSV" "DataFrames"

    # graphics
    "Plots" "GraphRecipes" "TikzPictures" "TikzGraphs" "NetworkLayout" "LayeredLayouts"
    "Makie" "GraphMakie" "CairoMakie" #"GLMakie"
    "GraphPlot" "Compose"
    # "SGtSNEpi" "Karnak"

    # "LogicCircuits"
  ]));
}