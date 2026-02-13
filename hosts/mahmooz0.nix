# this is for macos
{ config, pkgs, lib, inputs, myutils, ... }:

let
  taps = {
    "homebrew/homebrew-core" = inputs.homebrew-core;
    "homebrew/homebrew-cask" = inputs.homebrew-cask;
    # we need to add "homebrew-" prefix
    "slp/homebrew-krunkit" = inputs.krunkit;
  };
in
{
  config = {
    # required for nix-darwin to work
    system.stateVersion = 1;
    system.primaryUser = "${config.machine.user}";

    environment.systemPackages = with pkgs; [
      lima
      macpm # asitop
      # utm
    ];

    # necessary temporary fix
    ids.gids.nixbld = 350;

    environment.variables.HOMEBREW_NO_ANALYTICS = "1";

    users.users."${config.machine.user}" = {
      name = config.machine.user;
      # see the reference docs for more on user config:
      # https://nix-darwin.github.io/nix-darwin/manual/#opt-users.users
    };

    llms.llama-cpp.package = pkgs.llama-cpp;
    # llms.llama-cpp.package = inputs.llama-cpp-flake.packages.${pkgs.system}.default;

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
      casks = [
        "fuse-t"
        "raycast"
        "karabiner-elements"
        "xnviewmp"
        "openmtp"
        "jordanbaird-ice"
        "whatsapp"
        # "whisky"
        "obs"
        "transmission"
        "comfyui"
        "tor-browser"
        "cherry-studio"
        "lm-studio"
        # "audacious"
        # "deadbeef"
        # "petrichor"
        "swama"
        "shortcat"
        "keka"
        "lulu"
        "google-chrome"
        "sabnzbd"
        "wacom-tablet"
        "zoom"
        "slack"
        "rnote"
      ];
      brews = [
        "krunkit"
        "mole"
      ];
      global = {
        autoUpdate = false;
      };
      onActivation.autoUpdate = false;
      onActivation.upgrade = false;
      onActivation.cleanup = "uninstall";
      masApps = {
        # "XCode" = 497799835;
        # "Lockbook" = 1526775001;
        # "Lightroom" = 1451544217;
      };
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
          "/Applications/Transmission.app"
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
        ApplePressAndHoldEnabled = false;
        AppleKeyboardUIMode = 3; # full control/keyboard-navigation
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

    # we're using rosetta-builder instead of linux-builder now because it support x86 by default and works with rosetta 2 which is fast
    nix = {
      # linux-builder = {
      #   # https://github.com/nix-darwin/nix-darwin/issues/1192
      #   enable = true;
      #   ephemeral = true;
      #   maxJobs = 4;
      #   systems = [ "aarch64-linux" "x86_64-linux" ];
      #   config = {
      #     # i think this is a replacement for rosetta.enable = true?
      #     # boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
      #     virtualisation = {
      #       darwin-builder = {
      #         diskSize = 80 * 1024;
      #         memorySize = 8 * 1024;
      #       };
      #       cores = 8;
      #       rosetta.enable = true;
      #     };
      #   };
      # };
      settings.trusted-users = [ "@admin" ];
    };

    # nix-rosetta-builder = {
    #   enable = true;
    #   onDemand = true;
    #   cores = 8;
    #   memory = "32GiB";
    #   permitNonRootSshAccess = true;
    #   diskSize = "150GiB";
    #   onDemandLingerMinutes = 30;
    # };

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
  };
}