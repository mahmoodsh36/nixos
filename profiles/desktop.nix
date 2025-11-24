{ config, pkgs, lib, inputs, pkgs-master, pkgs-unstable, myutils, ... }:

let
  constants = (import ../lib/constants.nix);
  # main_julia = pkgs.julia;
in
{
  config = lib.mkIf config.machine.is_desktop {
    # some of the font options are commented out because they're not available on nix-darwin
    fonts = {
      # enableDefaultPackages = true;
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
      # fontDir.enable = true;
      # enableGhostscriptFonts = true;
      # fontconfig = {
      #   enable = true;
      #   antialias = true;
      #   cache32Bit = true;
      #   hinting.autohint = true;
      #   hinting.enable = true;
      # };
    };

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

      firefox
      neovide
      mpv

      # other
      # adb-sync
      ntfs3g
      gnupg
      graphviz
      isync
      notmuch
      monolith # save webpages
      djvulibre djvu2pdf
      czkawka czkawka-full # file dupe finder/cleaner? has a gui too
      # python3Packages.chromadb # vector database
      nodePackages.prettier
      nodejs pnpm
      exiftool
      spotdl
      openjdk
      transmission_4
      you-get aria2
      playwright
      uv
      argc
      imagemagickBig ghostscript # ghostscript is needed for some imagemagick commands
      ffmpeg-full.bin # untrunc-anthwlock
      pandoc
      pigz # for compression
      kando
      (pkgs.callPackage ../packages/vend.nix {})
      (pkgs.callPackage ../packages/better-adb-sync.nix {})

      # nix specific
      nixos-generators
      nix-prefetch-git
      nix-tree
      nixos-anywhere
      nix-init

      # some programming languages/environments
      (texlive.combined.scheme-full.withPackages((ps: with ps; [ pkgs.sagetex ])))
      typst
      # (lib.mkIf (!config.machine.enable_nvidia) pkgs.sageWithDoc) # to avoid building
      (lib.mkIf (!config.machine.enable_nvidia)
        (myutils.packageFromCommit {
          rev = "c2ae88e026f9525daf89587f3cbee584b92b6134b9";
          packageName = "sageWithDoc";
        }))

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
      pkgs.claude-code
      pkgs-master.aichat
      # opencode
      inputs.nix-ai-tools.packages.${pkgs.system}.opencode
      # inputs.nix-ai-tools.packages.${pkgs.system}.amp
      # gptme
      pkgs-master.antigravity
      youtube-music
      telegram-desktop
      darktable # image editor
      transmission_4-gtk

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
  };
}
