{ config, pkgs, lib, inputs, pkgs-unstable, myutils, pkgs-pinned, ... }:

 let
    constants = (import ../lib/constants.nix);
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
      neovide
      firefox
      pkgs-pinned.mpv
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
      # this causes build cuz of the yt-dlp overlay
      # jellyfin-tui jellytui

      # other
      # adb-sync
      ntfs3g
      gnupg
      graphviz
      isync
      notmuch
      monolith # save webpages
      djvulibre djvu2pdf
      # czkawka-full # file dupe finder/cleaner? has a gui too
      nodePackages.prettier
      nodejs pnpm yarn
      exiftool
      openjdk
      you-get aria2
      playwright
      uv
      argc
      imagemagickBig ghostscript # ghostscript is needed for some imagemagick commands
      ffmpeg-full.bin # untrunc-anthwlock
      pandoc
      pigz # for compression
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
      (lib.mkIf config.machine.can_compile
        (texlive.combined.scheme-full.withPackages((ps: with ps; [ pkgs.sagetex ]))))
      typst
      (myutils.packageFromCommit {
        rev = "c2ae88e026f9525daf89587f3cbee584b92b6134b9";
        packageName = "sageWithDoc";
        sha256 = "1fsnvjvg7z2nvs876ig43f8z6cbhhma72cbxczs30ld0cqgy5dks";
      })

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

      python3Packages.huggingface-hub
      qwen-code
      gemini-cli
      pkgs-unstable.claude-code
      aichat
      inputs.llm-agents.packages.${pkgs.system}.opencode
      pkgs.antigravity
      pre-commit

      youtube-music
      telegram-desktop
      darktable # image editor

      config.machine.llama-cpp.pkg
      whisper-cpp

      pkgs.gitingest
      spotdl
    ] ++ pkgs.lib.optionals (!config.machine.is_darwin) [
      # transmission fails on darwin due to fmt build issue
      transmission_4
      transmission_4-gtk
    ] ++ pkgs.lib.optionals config.machine.enable_nvidia [
      cudatoolkit nvtopPackages.full
      vllm
    ];
  };
}