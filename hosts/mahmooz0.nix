# this is for macos
{ config, pkgs, lib, inputs, pkgs-master, myutils, ... }:

let
  taps = {
    "homebrew/homebrew-core" = inputs.homebrew-core;
    "homebrew/homebrew-cask" = inputs.homebrew-cask;
    # we need to add "homebrew-" prefix
    "th-ch/homebrew-youtube-music" = inputs.yt-music-tap;
  };
in

{
  config = {
    # required for nix-darwin to work
    system.stateVersion = 1;
    system.primaryUser = "${config.machine.user}";

    environment.variables.HOMEBREW_NO_ANALYTICS = "1";

    users.users."${config.machine.user}" = {
      name = config.machine.user;
      # see the reference docs for more on user config:
      # https://nix-darwin.github.io/nix-darwin/manual/#opt-users.users
    };

    nix-homebrew = {
      taps = taps;
      # install homebrew under the default prefix
      enable = true;
      # apple silicon only: also install homebrew under the default intel prefix for rosetta 2
      enableRosetta = true;
      # user owning the homebrew prefix
      user = "${config.machine.user}";
      # with mutabletaps disabled, taps can no longer be added imperatively with `brew tap`.
      mutableTaps = false;
    };

    homebrew = {
      enable = true;
      # align homebrew taps config with nix-homebrew
      taps = builtins.attrNames config.nix-homebrew.taps;
      # taps = builtins.attrNames taps;
      # taps = [
      #   "nohajc/anylinuxfs"
      # ];
      casks = [
        "emacs-app"
        "wezterm"
        "firefox"
        "fuse-t"
        "mpv"
        "transmission"
        "raycast"
        # this errors out :/
        # "youtube-music"
        # "podman-desktop"
      ];
      brews = [
        # "anylinuxfs"
        # "pkg-config" "cmake" "make"
        # "ntfs-3g-mac"
        # "ext4fuse-mac"
        # "ext4fuse"
        # "gromgit/fuse/ntfs-3g-mac"
        # "rsync"
        "llama.cpp"
      ];
      onActivation.autoUpdate = true;
      onActivation.upgrade = true;
      onActivation.cleanup = "zap";
    };

    system.defaults = {
      dock = {
        autohide = true;
        persistent-apps = [
          "/Applications/Firefox.app"
          "/Applications/WezTerm.app"
          "/Applications/Emacs.app"
          "/Applications/Transmission.app"
        ];
      };
      finder.FXPreferredViewStyle = "clmv"; # column view
      loginwindow.GuestEnabled = false;
      NSGlobalDomain = {
        AppleICUForce24HourTime = true;
        AppleInterfaceStyle = "Dark";
        KeyRepeat = 1; # fastest
        InitialKeyRepeat = 15;
      };
    };

    # https://github.com/nix-darwin/nix-darwin/issues/1041
    # services.karabiner-elements = {
    #   enable = true;
    #   package = pkgs.karabiner-elements.overrideAttrs (old: {
    #     version = "14.13.0";
    #
    #     src = pkgs.fetchurl {
    #       inherit (old.src) url;
    #       hash = "sha256-gmJwoht/Tfm5qMecmq1N6PSAIfWOqsvuHU8VDJY8bLw=";
    #     };
    #
    #     dontFixup = true;
    #   });
    # };

    # other configuration parameters
    # see here: https://nix-darwin.github.io/nix-darwin/manual
  };
}
