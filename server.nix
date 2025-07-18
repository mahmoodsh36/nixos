{ config, pkgs, lib, inputs, pkgs-pinned, ... }:

let
  server_vars = (import ./server_vars.nix { inherit pkgs; inherit pkgs-pinned; inherit inputs; });
  constants = (import ./constants.nix);
  jellyfin_dir = "${constants.extra_storage_dir}/jellyfin";
in
{
  imports = [
    ./nvidia.nix
    ./network.nix
    ./llm.nix
  ];
  config = {
    _module.args = { inherit inputs; };

    boot.tmp.cleanOnBoot = true;
    system.etc.overlay.enable = false;
    time.timeZone = "Asia/Jerusalem";

    # use the systemd-boot EFI boot loader.
    # boot.loader.systemd-boot.enable = true;
    # boot.loader.efi.canTouchEfiVariables = true;

    # use grub
    boot.loader.systemd-boot.enable = false;
    # boot.supportedFilesystems = [ "ntfs" ];
    boot.loader.grub = {
      enable = true;
      efiSupport = true;
      useOSProber = true;
      devices = [ "nodev" ];
      copyKernels = true;
    };
    boot.loader.efi.canTouchEfiVariables = true;

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    # not needed with flakes and causes a bunch of warnings
    nix.channel.enable = false;

    # enable some programs/services
    programs.mosh.enable = true;
    programs.zsh.enable = true;
    programs.traceroute.enable = true;
    programs.direnv.enable = true;
    programs.git = {
      enable = true;
      package = pkgs.gitFull;
      lfs.enable = true;
    };
    programs.htop.enable = true;
    programs.iotop.enable = true;

    # gpg
    services.pcscd.enable = true;
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
    hardware.nvidia.open = false;
    hardware.nvidia-container-toolkit.enable = config.machine.enable_nvidia;

    hardware.graphics = {
      extraPackages = with pkgs; [
      ] ++ pkgs.lib.optionals config.machine.enable_nvidia [
        nvidia-vaapi-driver
      ];
    };

    # self-hosted media service
    services.jellyfin = {
      enable = config.machine.is_home_server;
      user = constants.myuser; # might need: sudo chown -R mahmooz:users /var/lib/jellyfin
      # this causes the directory to be created automatically even if my extra storage dir isnt mounted, which would then later prevent it from being mounted because the path is taken
      dataDir = lib.mkIf (builtins.pathExists constants.extra_storage_dir) jellyfin_dir;
    };
    systemd.services.jellyfin.unitConfig = {
      ConditionPathExists = constants.extra_storage_dir;
    };
    # need to set this up
    # services.jellyseerr.enable = true;

    # users
    users.users.mahmooz = {
      isNormalUser = true;
      extraGroups = [ "audio" "wheel" "podman" "incus-admin" "libvirtd" ];
      shell = pkgs.zsh;
      initialPassword = "123";
      packages = with pkgs; [];
    };

    environment.sessionVariables = rec {
      XDG_CACHE_HOME  = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME   = "$HOME/.local/share";
      XDG_STATE_HOME  = "$HOME/.local/state";
      # not officially in the specification
      XDG_BIN_HOME    = "$HOME/.local/bin";
      PATH = [
        "${XDG_BIN_HOME}"
      ];
      # this one fixes some problems with python matplotlib and probably some other qt applications
      QT_QPA_PLATFORM_PLUGIN_PATH = "${pkgs.qt5.qtbase.bin}/lib/qt-${pkgs.qt5.qtbase.version}/plugins";
      # QT_SCALE_FACTOR = "2";
      PYTHON_HISTORY = "$HOME/brain/python_history";

      BRAIN_DIR = constants.brain_dir;
      MUSIC_DIR = constants.music_dir;
      WORK_DIR = constants.work_dir;
      NOTES_DIR = constants.notes_dir;
      SCRIPTS_DIR = constants.scripts_dir;
      DOTFILES_DIR = constants.dotfiles_dir;
      NIX_CONFIG_DIR = constants.nix_config_dir;
      BLOG_DIR = constants.blog_dir;
      EDITOR = "nvim";
      BROWSER = "firefox";
      DATA_DIR = constants.data_dir;
      MPV_SOCKET_DIR = constants.mpv_socket_dir;
      MPV_MAIN_SOCKET_PATH = constants.mpv_main_socket_path;
      MODELS_DIR = constants.models_dir;
      MYGITHUB = constants.mygithub;
      PERSONAL_WEBSITE = constants.personal_website;
      MAHMOOZ3_ADDR = constants.mahmooz3_addr;
      MAHMOOZ2_ADDR = constants.mahmooz2_addr;
      MAHMOOZ1_ADDR = constants.mahmooz1_addr;
      MYDOMAIN = constants.mydomain;

    } // (if config.machine.enable_nvidia then {
      # do we really need these? hopefully it makes things work with jellyfin/firefox?
      LIBVA_DRIVER_NAME = "nvidia";
      VDPAU_DRIVER = "nvidia";
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      MOZ_DISABLE_RDD_SANDBOX= "1" ;
    } else {});

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

    environment.systemPackages = server_vars.server_packages;
    nixpkgs.overlays = server_vars.server_overlays;

    # wheel group doesnt need password for sudo
    security.sudo = {
      enable = true;
      wheelNeedsPassword = false;
      # execWheelOnly = true; # we may want this to be true for security
    };

    # didnt work for my other machine.. :/
    systemd.services.keepalive = {
      enable = false;
      description = "keep network connections alive";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.python3.withPackages (ps: with ps; [ aiohttp requests ])}/bin/python /home/mahmooz/work/scripts/keepalive.py";
        Restart = "always";
        RestartSec = 10;
        User = "mahmooz";
        NoNewPrivileges = true;
        ConditionPathExists = "/home/mahmooz/work/scripts/keepalive.py";
      };
      wantedBy = [ "multi-user.target" ];
    };

    # garbage collection
    nix.settings.auto-optimise-store = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # virtualization
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        ovmf = {
          enable = true;
          packages = with pkgs; [ OVMFFull.fd ];
        };
        swtpm.enable = true;
      };
    };
    virtualisation.podman = {
      enableNvidia = config.machine.enable_nvidia;
      dockerCompat = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
      enable = true;
      autoPrune.enable = true;
      extraPackages = [
        pkgs.curl
        pkgs.neovim
      ];
    };

    virtualisation.arion = {
      backend = "podman-socket";
      # projects.open-notebook = lib.mkIf config.machine.is_desktop {
      #   settings = {
      #     imports = [
      #       ./arion-open-notebook.nix
      #     ];
      #   };
      # };
      projects.mykhoj = lib.mkIf config.machine.is_desktop {
        settings = {
          imports = [
            ./khoj.nix
          ];
        };
      };
    };

    # will this help prevent the dbus org.freedesktop.secrets error when using goose-cli?
    # may also need it to avoid other issues
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.sddm.enableGnomeKeyring = true;

    system.stateVersion = "24.05"; # dont change
  };
}