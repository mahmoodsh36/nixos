{ config, pkgs, lib, inputs, pkgs-master, pkgs-unstable, myutils, ... }:

let
  constants = (import ../lib/constants.nix);
  # main_julia = pkgs.julia;
  emacs_base_pkg = inputs.emacs.packages.${pkgs.system}.emacs-git;
  emacs_pkg = (emacs_base_pkg.override {
    withImageMagick = false;
    withXwidgets = false;
    withPgtk = true;
    withNativeCompilation = true;
    withCompressInstall = false;
    withTreeSitter = true;
    withGTK3 = true;
    withX = false;
  }).overrideAttrs (oldAttrs: rec {
    imagemagick = pkgs.imagemagickBig;
  });
in
{
  imports = [
    ./desktop-linux.nix
  ];

  config = lib.mkIf config.machine.is_desktop {
    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        fantasque-sans-mono
        google-fonts
        cascadia-code
        nerd-fonts.inconsolata nerd-fonts.jetbrains-mono nerd-fonts.fira-code nerd-fonts.iosevka
        iosevka
        fira-code
        ubuntu-classic
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        dejavu_fonts
        cm_unicode
        unicode-emoji
        unicode-character-database
        unifont
        symbola
        # persian font
        vazir-fonts
        font-awesome
        corefonts # for good arabic/hebrew/etc fonts
        mplus-outline-fonts.githubRelease
        dina-font
        proggyfonts
        monaspace
      ];
      fontDir.enable = true;
      enableGhostscriptFonts = true;
      fontconfig = {
        enable = true;
        antialias = true;
        cache32Bit = true;
        hinting.autohint = true;
        hinting.enable = true;
      };
    };

    # helps finding the package that contains a specific file
    programs.nix-index = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
    };
    programs.command-not-found.enable = false; # needed for nix-index

    # packages
    environment.systemPackages = with pkgs; [
      # (pkgs.writeShellScriptBin "julia" ''
      #   export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
      #     pkgs.stdenv.cc.cc.lib
      #     pkgs.libGL
      #     pkgs.glib
      #     pkgs.zlib
      #   ]}:$LD_LIBRARY_PATH
      #   export DISPLAY=:0 # cheating so it can compile
      #   exec ${main_julia}/bin/julia "$@"
      # '')

      vdhcoapp # for firefox video download helper

      # other
      # adb-sync
      woeusb-ng
      ntfs3g
      gnupg
      graphviz
      isync
      notmuch
      monolith # save webpages
      quickemu # quickly start VMs
      ventoy
      djvulibre djvu2pdf
      czkawka czkawka-full # file dupe finder/cleaner? has a gui too
      # python3Packages.chromadb # vector database
      nodePackages.prettier
      nodejs pnpm
      exiftool
      spotdl
      openjdk
      transmission_4 acpi lm_sensors
      you-get aria2
      playwright
      uv
      argc
      cryptsetup
      imagemagickBig ghostscript # ghostscript is needed for some imagemagick commands
      ffmpeg-full.bin # untrunc-anthwlock
      pandoc
      pigz # for compression
      jellyfin-tui jellycli jellytui
      kando
      (pkgs.callPackage ../packages/vend.nix {})
      (pkgs.callPackage ../packages/better-adb-sync.nix {})

      # nix specific
      nixos-generators
      nix-prefetch-git
      nix-tree
      nixos-anywhere
      nix-init
      steam-run-free

      # some programming languages/environments
      (texlive.combined.scheme-full.withPackages((ps: with ps; [ pkgs.sagetex ])))
      typst
      (lib.mkIf (!config.machine.enable_nvidia) pkgs.sageWithDoc) # to avoid building
      # (lib.mkIf (!config.machine.enable_nvidia)
      #   (myutils.packageFromCommit {
      #     rev = "c2ae88e026f9525daf89587f3cbee584b92b6134b9";
      #     packageName = "sageWithDoc";
      #   }))

      # lsp
      nodePackages.bash-language-server
      nil
      python3Packages.python-lsp-server
      vscode-langservers-extracted

      # dictionary
      (aspellWithDicts (dicts: with dicts; [ en en-computers en-science ]))

      python3Packages.huggingface-hub
      pkgs-master.gemini-cli
      pkgs-master.qwen-code
      pkgs-master.claude-code

      config.machine.llama-cpp.pkg
      koboldcpp
      mistral-rs
      # i think this fixed an issue that existed in the nixpkgs version at the time
      # (whisper-cpp.overrideAttrs (old: {
      #   src = pkgs.fetchFromGitHub {
      #     owner = "ggml-org";
      #     repo = "whisper.cpp";
      #     rev = "c85b1ae84eecbf797f77a76a30e648c5054ee663";
      #     sha256 = "sha256-ABgsfkT7ghOGe2KvcnyP98J7mDI18BWtJGb1WheAduE=";
      #   };
      # }))
      whisper-cpp

      aichat
      opencode
      # gptme

      # https://github.com/natsukium/mcp-servers-nix/blob/main/pkgs/default.nix
      mcp-server-everything
      mcp-server-time
      mcp-server-git
      mcp-server-sequential-thinking
      mcp-server-filesystem
      playwright-mcp
      mcp-server-github github-mcp-server
      mcp-server-sqlite

      pkgs.gitingest
    ] ++ pkgs.lib.optionals config.machine.enable_nvidia [
      cudatoolkit nvtopPackages.full

      vllm

      stable-diffusion-webui.forge.cuda # for lllyasviel's fork of AUTOMATIC1111 WebUI
      stable-diffusion-webui.comfy.cuda # for ComfyUI
    ];

    # vector database for RAG
    services.qdrant = {
      enable = config.machine.is_desktop;
      settings.service.host = "0.0.0.0";
    };

    services.karakeep = {
      enable = true;
      extraEnvironment = {
        DISABLE_SIGNUPS = "true";
        DISABLE_NEW_RELEASE_CHECK = "true";
      };
    };

    # http://localhost:28981
    environment.etc."paperless-admin-pass".text = "admin";
    services.paperless = {
      # enable = true;
      passwordFile = "/etc/paperless-admin-pass";
    };

    programs.adb.enable = true;
    programs.java.enable = true;
    programs.sniffnet.enable = true;
    programs.wireshark.enable = true;
    programs.dconf.enable = true;

    services.mysql = {
      enable = false;
      settings.mysqld.bind-address = "0.0.0.0";
      package = pkgs.mariadb;
    };

    services.mongodb = {
      enable = false;
      bind_ip = "0.0.0.0";
    };

    services.postgresql = {
      enable = false;
      enableTCPIP = true;
      authentication = pkgs.lib.mkOverride 10 ''
      # generated file; do not edit!
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            trust
      host    all             all             ::1/128                 trust
      '';
      # package = pkgs.postgresql_16;
      ensureDatabases = [ "mahmooz" ];
      # port = 5432;
      initialScript = pkgs.writeText "backend-initScript" ''
        CREATE ROLE mahmooz WITH LOGIN PASSWORD 'mahmooz' CREATEDB;
        CREATE DATABASE test;
        GRANT ALL PRIVILEGES ON DATABASE test TO mahmooz;
      '';
      ensureUsers = [{
        name = "mahmooz";
        ensureDBOwnership = true;
      }];
    };

    services.open-webui = lib.mkIf (lib.and config.machine.is_desktop (!config.machine.enable_nvidia)) {
      enable = false;
      host = "0.0.0.0";
      port = 8083;
      environment = {
        WEBUI_AUTH = "False";
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
      };
    };

    services.podman-autobuilder.containers = {
      mlpython = lib.mkIf config.machine.enable_nvidia {
        imageName = "mlpython";
        context = ../containers/mlpython;
        buildArgs = [
          # "--memory=30g"
          # "--cpuset-cpus=0-9"
          "--network=host"
          "--build-arg" "MAX_JOBS=8"
        ];
        runArgs = [
          "--cdi-spec-dir=/run/cdi"
          "--device=nvidia.com/gpu=all"
          "--shm-size=64g"
          "-v" "${constants.models_dir}:${constants.models_dir}"
          "-v" "/:/host" # full filesystem access
          "--network=host"
          # "--security-opt" "seccomp=unconfined"
        ];
        command = [ "sleep" "infinity" ];
        aliases = {
          "mlpython" = {
            command = [ "python3" ];
            interactive = true;
          };
          "myvllm" = {
            command = [
              "python3" "-m" "vllm.entrypoints.openai.api_server"
              "--download-dir" "${constants.models_dir}" "--trust-remote-code"
              "--port" "5000" "--max-num-seqs" "1"
            ];
            interactive = true;
          };
        };
      };
      mineru = {
        imageName = "mineru";
        context = ../containers/mineru;
        buildArgs = [
          "--network=host"
        ];
        runArgs = [
          "-v" "/:/host"
          "--network=host"
        ] ++ pkgs.lib.optionals config.machine.enable_nvidia [
          "--cdi-spec-dir=/run/cdi"
          "--device=nvidia.com/gpu=all"
        ];
        command = [ "sleep" "infinity" ];
        aliases = {
          "minerupython" = {
            command = [ "python3" ];
            interactive = true;
          };
          "mineru" = {
            command = [ "mineru" ];
            interactive = true;
          };
        };
      };
    };

    # ccache is needed for robotnix
    nix.settings.extra-sandbox-paths = [ config.programs.ccache.cacheDir ];
    programs.ccache.enable = true;
  };
}