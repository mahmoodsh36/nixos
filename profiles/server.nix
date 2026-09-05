{ config, pkgs, lib, inputs, myutils, pkgs-pinned, pkgs-unstable, ... }:

let
  constants = (import ../lib/constants.nix);
in
{
  imports = [
    ../services/mpv-daemon.nix
    ./network.nix
  ];

  config = {
    time.timeZone = "Asia/Jerusalem";

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.settings.auto-optimise-store = true;
    nix.gc = {
      automatic = true;
      options = "--delete-older-than 10d";
    } // (if pkgs.stdenv.isDarwin
          then { interval = [{ Hour = 3; Minute = 15; }]; }
          else { dates = "daily"; });

    # not needed with flakes and causes a bunch of warnings
    nix.channel.enable = false;

    programs.direnv.enable = true;
    programs.zsh.enable = true;

    # for binaries of nonfree packages, like pytorch (otherwise nix will try to compile them)
    nix.settings.substituters = [
      "https://nix-community.cachix.org"
      "https://cache.nixos.org/"
    ];
    nix.settings.trusted-public-keys = [
      # compare to the key published at https://nix-community.org/cache
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    environment.systemPackages = with pkgs; [
      rsync
      sqlite
      jq
      ripgrep
      parallel
      fd # alternative to find
      dash
      lsof
      tree
      ncdu dust
      file
      zip unzip fzf p7zip
      gnupg
      openssl
      # we need wezterm installed on the server too, for persistent sessions
      wezterm
      bc # used for some arithmetic in shell scripts
      yt-dlp # ytdl-sub
      coreutils-full
      gh

      # networking tools
      curl wget socat
      inetutils rclone sshfs bind
    ] ++ pkgs.lib.optionals (!config.machine.low_resources) [
      git-filter-repo
      gcc clang clang-tools # gdb
      man-pages man-pages-posix
      podman-compose
      inputs.cltpt.packages.${pkgs.system}.default
      mpris-scrobbler
      inputs.mpv-history-daemon.packages.${pkgs.system}.default
      inputs.lem.packages.${pkgs.system}.lem-ncurses
      arp-scan iftop

      # some build systems
      cmake gnumake automake autoconf
      pkg-config

      # nix specific stuff
      nvfetcher
      inputs.disko.packages.${pkgs.system}.default
    ];

    # some apps respect XDG paths even on macos
    environment.variables = rec {
      XDG_CACHE_HOME  = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME   = "$HOME/.local/share";
      XDG_STATE_HOME  = "$HOME/.local/state";
      # not officially in the specification
      XDG_BIN_HOME    = "$HOME/.local/bin";
      WEZTERM_CONFIG_FILE = lib.mkIf config.machine.is_darwin "$HOME/.config/wezterm/wezterm.lua";
      # this one fixes some problems with python matplotlib and probably some other qt applications
    };

    nixpkgs.overlays = [
      inputs.niri-flake.overlays.niri
    ];

    # mpv history daemon
    mpv-daemon.enable = !config.machine.low_resources;
  };
}