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
    # "LightGraphs" "HTTP" "OhMyREPL" "MLJ"
    # "Luxor" "ReinforcementLearningBase" "DataStructures" "RecipesBase"
    # "Latexify" "Distributions" "Gen" "UnicodePlots" "StaticArrays"
    # "Genie" "WaterLily"
    # "ForwardDiff" "Metatheory" "TermInterface" "SymbolicRegression"
    # "Transformers" "Optimization" "Knet" "ModelingToolkit" "StatsPlots" "Zygote"
    # "Flux" "JET" "LoopVectorization" "Weave" "BrainFlow"
    # "CUDA" "Javis" "GalacticOptim" "Dagger" "Interact"
    # "Gadfly" "Turing" "RecipesPipeline"

    # "Images"
    "LanguageServer"

    # math
    "Graphs" "MetaGraphs"
    # "Symbolics" "SymbolicUtils"

    # data processing
    "JSON" "CSV" "DataFrames"

    # graphics
    "Plots" "GraphRecipes"
    # "Makie" "GLMakie"
    # "SGtSNEpi" "Karnak"
    # "TikzPictures" "NetworkLayout"
  ]));
}