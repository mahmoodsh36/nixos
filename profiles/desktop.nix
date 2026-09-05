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
        dejavu_fonts
      ] ++ pkgs.lib.optionals (!config.machine.low_resources) [
        fantasque-sans-mono
        google-fonts
        # cm_unicode
        # unicode-emoji
        # unicode-character-database
        corefonts # for good arabic/hebrew/etc fonts
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
      pkgs-pinned.firefox
      pkgs-pinned.mpv
      ntfs3g
      gnupg
      uv

      nix-prefetch-git
      nix-tree
    ] ++ pkgs.lib.optionals (!config.machine.low_resources) [
      inputs.lem.packages.${pkgs.system}.lem-webview-app

      pkgs-pinned.ffmpeg-full.bin # untrunc-anthwlock
      pandoc
      llama-cpp
      graphviz
      isync notmuch
      djvulibre djvu2pdf
      prettier
      exiftool
      argc
      imagemagickBig ghostscript # ghostscript is needed for some imagemagick commands
      pigz # for compression
      (pkgs.callPackage ../packages/better-adb-sync.nix {})
      android-tools
      scrcpy
      xournalpp pkgs-pinned.rnote # krita
      telegram-desktop

      # nix specific
      nixos-generators
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
      bash-language-server
      typescript-language-server
      python3Packages.python-lsp-server
      vscode-langservers-extracted

      # dictionary
      (aspellWithDicts (dicts: with dicts; [ en en-computers en-science ]))

      python3Packages.huggingface-hub
      inputs.llm-agents.packages.${pkgs.system}.opencode
      inputs.llm-agents.packages.${pkgs.system}.antigravity-cli
    ] ++ pkgs.lib.optionals (!config.machine.is_darwin && !config.machine.low_resources) [
      # transmission fails on darwin due to fmt build issue
      transmission_4
      transmission_4-gtk
    ] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
      # x86_64-only upstream binaries (no aarch64-linux builds).
      pkgs.discord
    ];
  };
}