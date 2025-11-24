# this is for macos
{ config, pkgs, lib, inputs, pkgs-master, myutils, ... }:

let
  taps = {
    "homebrew/homebrew-core" = inputs.homebrew-core;
    "homebrew/homebrew-cask" = inputs.homebrew-cask;
    # we need to add "homebrew-" prefix
    "Neved4/homebrew-tap" = inputs.neved4-tap;
    "slp/homebrew-krunkit" = inputs.krunkit;
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

    # machine.llama-cpp.pkg = inputs.llama-cpp-flake.packages.${pkgs.system}.default;

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
        # "wezterm"
        "fuse-t"
        "raycast"
        # this errors out :/
        # "youtube-music"
        # "podman-desktop"
        # "pear"
        "karabiner-elements"
        "utm"
        "xnviewmp"
        "openmtp"
        "jordanbaird-ice"
        "runescape"
        "utm"
        "whatsapp"
        "whisky"
        "google-chrome"
        "obs"
      ];
      brews = [
        "krunkit"
        # "mlx-lm"
        # "anylinuxfs"
        # "pkg-config" "cmake" "make"
        # "ntfs-3g-mac"
        # "ext4fuse-mac"
        # "ext4fuse"
        # "gromgit/fuse/ntfs-3g-mac"
        # "rsync"
        # "llama.cpp"
      ];
      onActivation.autoUpdate = true;
      onActivation.upgrade = true;
      onActivation.cleanup = "zap";
      # masApps = {
      #   "XCode" = 497799835;
      #   "Lockbook" = 1526775001;
      #   "Lightroom" = 1451544217;
      # };
    };

    system.defaults = {
      dock = {
        autohide = true;
        # magnification = true;
        # mineffect = "scale";
        tilesize = 40;
        autohide-delay = 0.2;
        autohide-time-modifier = 0.1;
        persistent-apps = [
          "/Applications/Nix Apps/Firefox.app"
          "/Applications/Nix Apps/WezTerm.app"
          "/Applications/Nix Apps/Emacs.app"
          "/Applications/Nix Apps/Transmission.app"
        ];
      };
      finder = {
        ShowPathbar = true;
        ShowStatusBar = true;
        FXPreferredViewStyle = "clmv"; # column view
      };
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
      };
      loginwindow.GuestEnabled = false;
      NSGlobalDomain = {
        AppleICUForce24HourTime = true;
        AppleInterfaceStyle = "Dark";
        KeyRepeat = 1; # fastest
        InitialKeyRepeat = 15;
        AppleShowAllExtensions = true;
        "com.apple.trackpad.enableSecondaryClick" = true;
      };
      CustomUserPreferences = {
        # settings of plist in /Users/${vars.user}/Library/Preferences/
        "com.apple.finder" = {
          # set home directory as startup window
          NewWindowTargetPath = "file:///Users/${config.machine.user}/";
          NewWindowTarget = "PfHm";
          # set search scope to directory
          # FXDefaultSearchScope = "SCcf";
          # multi-file tab view
          FinderSpawnTab = true;
        };
        "com.apple.desktopservices" = {
          # disable creating .DS_Store files in network an USB volumes
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        # show battery percentage
        "/Users/${config.machine.user}/Library/Preferences/ByHost/com.apple.controlcenter".BatteryShowPercentage = true;
        # privacy
        "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
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
