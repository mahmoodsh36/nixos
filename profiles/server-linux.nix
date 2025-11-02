{ config, pkgs, lib, inputs, pkgs-master, myutils, ... }:

let
  constants = (import ../lib/constants.nix);
in
{
  config = lib.mkIf config.machine.is_linux {
    system.stateVersion = "24.05"; # dont change

    _module.args = {
      inherit inputs;
    };

    boot.tmp.cleanOnBoot = true;
    system.etc.overlay.enable = false;

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

    # users
    users.users.mahmooz = {
      isNormalUser = true;
      extraGroups = [ "audio" "wheel" "podman" "incus-admin" "libvirtd" "caddy" ];
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
      LLAMA_CACHE = lib.mkIf (builtins.pathExists constants.models_dir) constants.models_dir;
    } // (if config.machine.enable_nvidia then {
      # do we really need these? hopefully it makes things work with jellyfin/firefox?
      LIBVA_DRIVER_NAME = "nvidia";
      VDPAU_DRIVER = "nvidia";
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      MOZ_DISABLE_RDD_SANDBOX= "1" ;
    } else {});


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

    # virtualization
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
      };
    };
    virtualisation.podman = {
      package = config.machine.podman.pkg;
      enableNvidia = config.machine.enable_nvidia;
      dockerCompat = true;
      dockerSocket.enable = true;
      defaultNetwork.settings = {
        dns_enabled = true;
        # dns_servers = [ "8.8.8.8" "1.1.1.1" ];
      };
      enable = true;
      autoPrune.enable = true;
      # dont add extraPackages on server to avoid building (building podman is resource intensive..)
      extraPackages = lib.mkIf config.machine.is_desktop [
        pkgs.curl
        pkgs.neovim
        pkgs.git
      ];
    };
    # see: https://github.com/containers/podman/blob/main/troubleshooting.md#26-running-containers-with-resource-limits-fails-with-a-permissions-error
    systemd.services."user@".serviceConfig = {
      Delegate = "cpu cpuset io memory pids";
    };

    # will this help prevent the dbus org.freedesktop.secrets error when using goose-cli?
    # may also need it to avoid other issues
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.sddm.enableGnomeKeyring = true;

    zramSwap.enable = true;
    # zramSwap.memoryPercent = 50; # 50% of available ram
    zramSwap.memoryMax = (10 * 1024 * 1024 * 1024); # 10gb
  };
}