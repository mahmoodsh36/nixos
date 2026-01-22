{ config, pkgs, lib, inputs, pkgs-unstable, myutils, pkgs-pinned, ... }:

 let
    constants = (import ../lib/constants.nix);
    # main_julia = pkgs.julia;
  in
{
  imports = [
    ./emacs.nix
  ];
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
        pkgs-pinned.noto-fonts-color-emoji
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
      pkgs-pinned.zed-editor

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

      neovide
      waveterm
      pkgs-pinned.firefox
      mpv
      inputs.lem.packages.${pkgs.system}.lem-webview

      # music
      # strawberry
      spotube
      # tauon
      # (deadbeef-with-plugins.override {
      #   plugins = with deadbeefPlugins; [
      #     mpris2
      #     statusnotifier
      #     lyricbar
      #     waveform-seekbar
      #     # playlist-manager
      #     # musical-spectrum
      #   ];
      # })
      # audacious
      jellyfin-tui jellytui

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
      yarn
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
      android-tools
      xournalpp rnote # krita

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
      (lib.mkIf (!config.machine.enable_nvidia && !config.machine.is_vm)
        (myutils.packageFromCommit {
          rev = "c2ae88e026f9525daf89587f3cbee584b92b6134b9";
          packageName = "sageWithDoc";
          sha256 = "1fsnvjvg7z2nvs876ig43f8z6cbhhma72cbxczs30ld0cqgy5dks";
        }))

      # lsp
      nodePackages.bash-language-server
      typescript-language-server
      python3Packages.python-lsp-server
      yaml-language-server
      tailwindcss-language-server
      postgres-language-server
      lua-language-server
      java-language-server
      dockerfile-language-server
      dot-language-server
      cmake-language-server
      bash-language-server
      autotools-language-server
      llm-ls
      vscode-langservers-extracted
      nil

      # dictionary
      (aspellWithDicts (dicts: with dicts; [ en en-computers en-science ]))

      pkgs-pinned.python3Packages.huggingface-hub
      gemini-cli
      qwen-code
      claude-code
      aichat
      # goose-cli
      inputs.nix-ai-tools.packages.${pkgs.system}.opencode # opencode
      mistral-vibe
      antigravity
      (pkgs.callPackage ../packages/gptme.nix {})
      pre-commit

      youtube-music
      telegram-desktop
      darktable # image editor
      transmission_4-gtk

      config.machine.llama-cpp.pkg
      koboldcpp
      mistral-rs
      whisper-cpp

      pkgs.gitingest
    ] ++ pkgs.lib.optionals config.machine.enable_nvidia [
      cudatoolkit nvtopPackages.full
      vllm
    ];
  };
}