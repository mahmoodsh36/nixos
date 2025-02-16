{ pkgs, pinned-pkgs, ... }:

{
  desktop_python = (pinned-pkgs.python3.withPackages (ps: with ps; [
    matplotlib flask requests numpy pandas
    # sympy scipy panflute jupyter jupyter-core
    beautifulsoup4 seaborn pillow dash rich networkx
    # dpkt python-lsp-server opencv4
    # graphviz flask-sqlalchemy flask-cors ariadne graphene mysql-connector

    # machine learning
    (if (import ./per_machine_vars.nix {}).enable_nvidia
     then torchWithCuda
     else torch)
    # scikit-learn
    transformers
    # diffusers
    # spacy gensim nltk
    datasets

    # for system
    evdev pyzmq python-magic
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