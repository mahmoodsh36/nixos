{ config, pkgs, lib, inputs, pkgs-master, myutils, pkgs-pinned, ... }:

let
  constants = (import ../lib/constants.nix);
in
{
  imports = [
    ../services/llm.nix
    ../services/mpv-daemon.nix
    ./network.nix
  ];

  config = {
    # _module.args = {
    #   inherit inputs;
    # };

    time.timeZone = "Asia/Jerusalem";

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
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
    ];
    nix.settings.trusted-public-keys = [
      # compare to the key published at https://nix-community.org/cache
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "llama-cpp.cachix.org-1:H75X+w83wUKTIPSO1KWy9ADUrzThyGs8P5tmAbkWhQc="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];

    environment.systemPackages = with pkgs; [
      rsync
      sqlite
      jq
      ripgrep
      parallel
      fd # alternative to find
      dash
      lsof tree
      tree-sitter
      glances btop ncdu
      gcc clang gdb clang-tools
      file zip unzip fzf p7zip unrar-wrapper
      gnupg
      openssl
      man-pages man-pages-posix
      # wezterm # we need it installed on the server too, for persistent sessions
      # (myutils.packageFromCommit {
      #   rev = "ab0f3607a6c7486ea22229b92ed2d355f1482ee0";
      #   packageName = "wezterm";
      # })
      wezterm
      # inputs.wezterm.packages.${pkgs.system}.default
      fdupes
      # jellyfin jellyfin-web
      miller
      bc # used for some arithmetic in shell scripts
      postgresql
      devenv
      podman-compose
      sbcl.pkgs.qlot-cli
      ytdl-sub pkgs-master.yt-dlp
      # (yt-dlp.overrideAttrs (finalAttrs: prevAttrs: {
      #   src = pkgs.fetchFromGitHub {
      #     owner = "yt-dlp";
      #     repo = "yt-dlp";
      #     rev = "a75399d89f90b249ccfda148987e10bc688e2f84";
      #     sha256 = "sha256-jQaENEflaF9HzY/EiMXIHgUehAJ3nnDT9IbaN6bDcac=";
      #   };
      # }))
      inputs.cltpt.packages.${pkgs.system}.default
      expect # for unbuffer etc
      mpris-scrobbler
      coreutils-full
      inputs.mpv-history-daemon.packages.${pkgs.system}.default
      git-filter-repo

      # networking tools
      curl wget nmap socat arp-scan tcpdump iftop
      inetutils rclone sshfs bind

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
        pkgs-pinned.ramalama
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
      inputs.mcp-servers-nix.overlays.default
      inputs.stable-diffusion-webui-nix.overlays.default
      inputs.niri-flake.overlays.niri
      # TODO: needed for robotnix.. but im not using this..
      (self: super: {
        ccacheWrapper = super.ccacheWrapper.override {
          extraConfig = ''
            export CCACHE_COMPRESS=1
            export CCACHE_DIR="${config.programs.ccache.cacheDir}"
            export CCACHE_UMASK=007
            export CCACHE_SLOPPINESS=random_seed
            if [ ! -d "$CCACHE_DIR" ]; then
              echo "====="
              echo "Directory '$CCACHE_DIR' does not exist"
              echo "Please create it with:"
              echo "  sudo mkdir -m0770 '$CCACHE_DIR'"
              echo "  sudo chown root:nixbld '$CCACHE_DIR'"
              echo "====="
              exit 1
            fi
            if [ ! -w "$CCACHE_DIR" ]; then
              echo "====="
              echo "Directory '$CCACHE_DIR' is not accessible for user $(whoami)"
              echo "Please verify its access permissions"
              echo "====="
              exit 1
            fi
          '';
        };
      })
    ];

    llms = {
      enable = true;
      modelsDirectory = "${config.machine.voldir}/models";
      llama-cpp.enable = config.machine.name == "mahmooz0";
      # llama-cpp-embeddings.enable = config.machine.name == "mahmooz0";
    };

    # mpv history daemon
    mpv-daemon.enable = true;
  };
}