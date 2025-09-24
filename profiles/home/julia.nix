{ lib, pkgs, config, config', ... }:

{
  config = lib.mkIf config'.machine.is_desktop {
    home.packages = [
      (pkgs.julia.withPackages.override ({
        precompile = true;
        # extraLibs = [
        #   pkgs.stdenv.cc.cc.lib
        #   pkgs.libgl
        #   pkgs.glib
        #   pkgs.zlib
        # ];
        makeWrapperArgs = [
          "--prefix LD_LIBRARY_PATH : /run/opengl-driver/lib"
        ];
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
        "Makie" "GraphMakie" "CairoMakie" # "GLMakie"
        "GraphPlot" "Compose"
        "SGtSNEpi" "Karnak"

        "LogicCircuits"
      ]))
    ];

    # sourced every time the `julia` is started
    home.file.".julia/config/startup.jl".text =
      let
        startup-packages = [
          "LinearAlgebra" # builtin
          "Statistics" # builtin
          "Random" # builtin
          "OhMyREPL"
        ];
      in
      ''
        ${pkgs.lib.concatStringsSep "\n" (map (pkg: "using ${pkg}") startup-packages)}

        atreplinit() do repl
          println("loaded:")
          for pkg in [${pkgs.lib.concatStringsSep ", " (map (pkg: ''"${pkg}"'') startup-packages)}]
            println(" - $pkg")
          end
        end
      '';

    # https://timholy.github.io/Revise.jl/stable/config/#Using-Revise-automatically-within-Jupyter/IJulia
    # home.file."julia/config/startup_ijulia.jl".text =
    #   # julia
    #   ''
    #     try
    #         @eval using Revise
    #     catch e
    #         @warn "Error initializing Revise" exception=(e, catch_backtrace())
    #     end
    #   '';

    # https://timholy.github.io/Revise.jl/stable/config/#Manual-revision:-JULIA_REVISE
    home.sessionVariables.JULIA_REVISE = "auto"; # "auto" | "manual"
  };
}