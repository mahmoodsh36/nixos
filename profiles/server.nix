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
    # _module.args = {
    #   inherit inputs;
    # };

    time.timeZone = "Asia/Jerusalem";

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.settings.auto-optimise-store = true;
    # not needed with flakes and causes a bunch of warnings
    nix.channel.enable = false;

    programs.direnv.enable = true;
    programs.zsh.enable = true;

    # for binaries of nonfree packages, like pytorch (otherwise nix will try to compile them)
    nix.settings.substituters = [
      "https://nix-community.cachix.org"
      "https://cache.nixos.org/"
      "https://llama-cpp.cachix.org"
      "https://cuda-maintainers.cachix.org"
      "https://robotnix.cachix.org"
    ];
    nix.settings.trusted-public-keys = [
      # compare to the key published at https://nix-community.org/cache
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "llama-cpp.cachix.org-1:H75X+w83wUKTIPSO1KWy9ADUrzThyGs8P5tmAbkWhQc="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "robotnix.cachix.org-1:+y88eX6KTvkJyernp1knbpttlaLTboVp4vq/b24BIv0="
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
      btop ncdu glances
      file zip unzip fzf p7zip unrar-wrapper
      gnupg
      openssl
      # we need wezterm installed on the server too, for persistent sessions
      wezterm
      bc # used for some arithmetic in shell scripts
      yt-dlp # ytdl-sub
      expect # for unbuffer etc
      coreutils-full
      gh

      # networking tools
      curl wget socat
      inetutils rclone sshfs bind
    ] ++ pkgs.lib.optionals (!config.machine.low_resources) [
      git-filter-repo
      gcc clang clang-tools # gdb
      man-pages man-pages-posix
      fdupes
      pkgs-pinned.jellyfin pkgs-pinned.jellyfin-web
      miller
      postgresql
      devenv
      podman-compose
      inputs.cltpt.packages.${pkgs.system}.default
      mpris-scrobbler
      inputs.mpv-history-daemon.packages.${pkgs.system}.default
      dust
      inputs.lem.packages.${pkgs.system}.lem-ncurses

      # heavier networking tools
      nmap arp-scan tcpdump iftop

      # some build systems
      cmake gnumake automake autoconf
      pkg-config
      rustc cargo

      # nix specific stuff
      compose2nix
      nvfetcher
      # arion
      inputs.disko.packages.${pkgs.system}.default
    ] ++ pkgs.lib.optionals config.machine.is_darwin [
      # pkgs-pinned.python3Packages.mlx-lm
      # pkgs-pinned.python3Packages.mlx-vlm
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
      QT_QPA_PLATFORM_PLUGIN_PATH = "${pkgs.qt5.qtbase.bin}/lib/qt-${pkgs.qt5.qtbase.version}/plugins";
      # QT_SCALE_FACTOR = "2";
    } // (if config.machine.enable_nvidia then {
      # do we really need these? hopefully it makes things work with jellyfin/firefox?
      LIBVA_DRIVER_NAME = "nvidia";
      VDPAU_DRIVER = "nvidia";
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      MOZ_DISABLE_RDD_SANDBOX= "1" ;
    } else {});

    nixpkgs.overlays = [
      inputs.nix-alien.overlays.default
      inputs.niri-flake.overlays.niri
    ];

    # mpv history daemon
    mpv-daemon.enable = !config.machine.low_resources;
  };
}