{ pkgs, ... }: {
  desktop_python = (pkgs.python3.withPackages (ps: with ps; [
    matplotlib flask requests panflute numpy jupyter jupyter-core pandas sympy scipy
    beautifulsoup4 seaborn pillow dash mysql-connector
    rich networkx dpkt python-lsp-server opencv4
    graphviz flask-sqlalchemy flask-cors ariadne graphene
    python-magic

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
  desktop_julia = (pkgs.julia.withPackages.override({ precompile = true; })([
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

    "OhMyREPL"
    "Metatheory"
    "Latexify"
    # "Flux"
    "CUDA" "MLJ"

    "Images"
    "LanguageServer"

    # math
    "Graphs" "MetaGraphs" "MetaGraphsNext"
    # "Symbolics" "SymbolicUtils"

    # data processing
    "JSON" "CSV" "DataFrames"

    # graphics
    "Plots" "GraphRecipes" "TikzPictures" "TikzGraphs" "NetworkLayout" "LayeredLayouts"
    "Makie" "GraphMakie" "CairoMakie" #"GLMakie"
    "GraphPlot" "Compose"
    # "SGtSNEpi" "Karnak"
  ]));
}