{ config, pkgs, lib, inputs, pkgs-master, myutils, ... }:

let
  constants = (import ../lib/constants.nix);
in
{
  imports = [
    ./nvidia.nix
    # ./network.nix
  ];

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

    environment.systemPackages = with pkgs; [
      lshw
      libva-utils
      nethogs
    ];

    # enable some programs/services
    programs.git = {
      enable = true;
      package = pkgs.gitFull;
      lfs.enable = true;
    };
    programs.htop.enable = true;
    programs.iotop.enable = true;
    programs.java.enable = true;
    programs.mosh.enable = true;
    programs.sniffnet.enable = true;
    programs.wireshark.enable = true;
    programs.traceroute.enable = true;

    hardware.graphics = {
      enable = true;
      # enable32Bit = true;
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
    users.users."${config.machine.user}" = {
      isNormalUser = true;
      extraGroups = [ "audio" "wheel" "podman" "incus-admin" "libvirtd" "caddy" ];
      shell = pkgs.zsh;
      initialPassword = "123";
      packages = with pkgs; [];
    };

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
        ExecStart = "${pkgs.python3.withPackages (ps: with ps; [ aiohttp requests ])}/bin/python /home/${config.machine.user}/work/scripts/keepalive.py";
        Restart = "always";
        RestartSec = 10;
        User = "${config.machine.user}";
        NoNewPrivileges = true;
        ConditionPathExists = "/home/${config.machine.user}/work/scripts/keepalive.py";
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

    # self-hosted media service
    services.declarative-jellyfin = {
      enable = config.machine.is_home_server;
      system = {
        serverName = "My Declarative Jellyfin Server";
        # use hardware acceleration for trickplay image generation
        trickplayOptions = lib.mkIf config.machine.enable_nvidia {
          enableHwAcceleration = true;
          enableHwEncoding = true;
        };
        UICulture = "en";
      };
      users.mahmooz = {
        mutable = false; # overwrite user settings
        permissions.isAdministrator = true;
        password = "mahmooz";
      };
      libraries = {
        Movies = lib.mkIf (builtins.pathExists "${constants.extra_storage_dir}/movies") {
          enabled = true;
          contentType = "movies";
          pathInfos = [ "${constants.extra_storage_dir}/movies" ];
        };
        Shows = lib.mkIf (builtins.pathExists "${constants.extra_storage_dir}/shows") {
          enabled = true;
          contentType = "tvshows";
          pathInfos = [ "${constants.extra_storage_dir}/shows" ];
        };
        # Books = lib.mkIf (builtins.pathExists "${constants.brain_dir}/resources" ) {
        #   enabled = true;
        #   contentType = "books";
        #   pathInfos = [ "${constants.brain_dir}/resources" ];
        # };
        # Music = lib.mkIf (builtins.pathExists "${constants.extra_storage_dir}/music" ) {
        #   enabled = true;
        #   contentType = "music";
        #   pathInfos = [ "${constants.extra_storage_dir}/music" ];
        # };
      };
      # hardware acceleration
      encoding = lib.mkIf config.machine.enable_nvidia {
        enableHardwareEncoding = true;
        hardwareAccelerationType = "vaapi";
        enableDecodingColorDepth10Hevc = true;
        allowHevcEncoding = true;
        allowAv1Encoding = true;
        hardwareDecodingCodecs = [
          "h264"
          "hevc"
          "mpeg2video"
          "vc1"
          "vp9"
          "av1"
        ];
      };
      plugins = [
        {
          name = "intro skipper";
          url = "https://github.com/intro-skipper/intro-skipper/releases/download/10.10/v1.10.10.19/intro-skipper-v1.10.10.19.zip";
          version = "1.10.10.19";
          targetAbi = "10.10.7.0"; # required as intro-skipper doesn't provide a meta.json file
          sha256 = "sha256:12hby8vkb6q2hn97a596d559mr9cvrda5wiqnhzqs41qg6i8p2fd";
        }
        {
          name = "jellyfin-plugin-listenbrainz";
          url = "https://github.com/lyarenei/jellyfin-plugin-listenbrainz/releases/download/5.2.0.4/listenbrainz_5.2.0.4.zip";
          version = "5.2.0.4";
          targetAbi = "10.10.0.0";
          sha256 = "sha256:1fbh0ajjvgm879jkj3y77jy49axyax0gh2kiqp9m7phsb1330qvl";
        }
      ];
      # this is from older config of builtin jellyfin service
      # user = constants.myuser; # might need: sudo chown -R mahmooz:users /var/lib/jellyfin
      # this causes the directory to be created automatically even if my extra storage dir isnt mounted, which would then later prevent it from being mounted because the path is taken
      # dataDir = lib.mkIf (builtins.pathExists constants.extra_storage_dir) jellyfin_dir;
    };
    # systemd.services.jellyfin.unitConfig = {
    #   ConditionPathExists = constants.extra_storage_dir;
    # };
    # need to set this up
    # services.jellyseerr.enable = true;

    # services.karakeep = {
    #   enable = true;
    #   extraEnvironment = {
    #     DISABLE_SIGNUPS = "true";
    #     DISABLE_NEW_RELEASE_CHECK = "true";
    #   };
    # };

    services.mysql = {
      enable = false;
      settings.mysqld.bind-address = "0.0.0.0";
      package = pkgs.mariadb;
    };

    services.mongodb = {
      enable = false;
      bind_ip = "0.0.0.0";
    };

    # vector database for RAG
    services.qdrant = {
      enable = config.machine.is_desktop;
      settings.service.host = "0.0.0.0";
    };

    # http://localhost:28981
    environment.etc."paperless-admin-pass".text = "admin";
    services.paperless = {
      # enable = true;
      passwordFile = "/etc/paperless-admin-pass";
    };

    services.postgresql = {
      enable = false;
      enableTCPIP = true;
      authentication = pkgs.lib.mkOverride 10 ''
      # generated file; do not edit!
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            trust
      host    all             all             ::1/128                 trust
      '';
      # package = pkgs.postgresql_16;
      ensureDatabases = [ "mahmooz" ];
      # port = 5432;
      initialScript = pkgs.writeText "backend-initScript" ''
        CREATE ROLE mahmooz WITH LOGIN PASSWORD 'mahmooz' CREATEDB;
        CREATE DATABASE test;
        GRANT ALL PRIVILEGES ON DATABASE test TO mahmooz;
      '';
      ensureUsers = [{
        name = "mahmooz";
        ensureDBOwnership = true;
      }];
    };


    services.open-webui = lib.mkIf (lib.and config.machine.is_desktop (!config.machine.enable_nvidia)) {
      enable = false;
      host = "0.0.0.0";
      port = 8083;
      environment = {
        WEBUI_AUTH = "False";
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
      };
    };

    # virtualisation.arion = {
    #   backend = "podman-socket";
    #   projects.open-notebook = lib.mkIf config.machine.is_desktop {
    #     settings = {
    #       imports = [
    #         ./arion-open-notebook.nix
    #       ];
    #     };
    #   };
    # };

    zramSwap.enable = true;
    # zramSwap.memoryPercent = 50; # 50% of available ram
    zramSwap.memoryMax = (10 * 1024 * 1024 * 1024); # 10gb
  };
}