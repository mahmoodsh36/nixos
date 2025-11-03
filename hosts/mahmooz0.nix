# this is for macos
{ config, pkgs, lib, inputs, pkgs-master, myutils, ... }:

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

    homebrew = {
      enable = true;
      taps = [
        # for ntfs-3g and macfuse
        # "gromgit/homebrew-fuse"
        # remove this next time, its not needed since fuse-t can be grabbed without it
        # "macos-fuse-t/cask"
        # "nohajc/anylinuxfs"
      ];
      casks = [
        "emacs-app"
        "wezterm"
        "firefox"
        # "macfuse"
        # "osxfuse"
        "fuse-t"
        "mpv"
        "yt-music"
        "transmission"
        "raycast"
      ];
      brews = [
        # "anylinuxfs"
        # "pkg-config" "cmake" "make"
        # "ntfs-3g-mac"
        # "ext4fuse-mac"
        # "ext4fuse"
        # "gromgit/fuse/ntfs-3g-mac"
        # "rsync"
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
          "/Applications/YT Music.app"
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
    # other configuration parameters
    # see here: https://nix-darwin.github.io/nix-darwin/manual
  };
}