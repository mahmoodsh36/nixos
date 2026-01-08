{ system, config, pkgs, lib, inputs, pkgs-master, myutils, self, ... }:

let
  constants = (import ../lib/constants.nix);
in
{
  imports = [
    ./nvidia.nix
    ../services/jellyfin.nix
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
      cryptsetup
      (pkgs.writeShellScriptBin "unlock-data" ''
        set -e
        echo -n "enter LUKS password: "
        read -s password
        echo ""

        echo "unlocking disk1 (crypted1)..."
        echo -n "$password" | sudo cryptsetup open /dev/disk/by-id/ata-ST18000NM000J-2TV103_WR50CE23-part1 crypted1 -

        echo "unlocking disk2 (crypted2)..."
        echo -n "$password" | sudo cryptsetup open /dev/disk/by-id/ata-ST18000NM000J-2TV103_WR50H9LF-part1 crypted2 -

        # clear password from memory (best effort in shell)
        unset password

        echo "mounting /data..."
        sudo mount /data

        echo "done! /data is mounted."
      '')
      (pkgs.writeShellScriptBin "lock-data" ''
        set -e
        echo "unmounting /data..."
        sudo umount /data || true

        echo "locking disk2 (crypted2)..."
        sudo cryptsetup close crypted2

        echo "locking disk1 (crypted1)..."
        sudo cryptsetup close crypted1

        echo "done! /data is unmounted and disks are locked."
      '')
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

    hardware.nvidia.open = false;
    hardware.nvidia-container-toolkit.enable = config.machine.enable_nvidia;

    hardware.graphics = {
      enable = true;
      # enable32Bit = true;
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
      initialPassword = constants.password;
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

    # zramSwap.enable = true;
    # zramSwap.memoryPercent = 50; # 50% of available ram
    # zramSwap.memoryMax = (10 * 1024 * 1024 * 1024); # 10gb

    virtualisation.vmVariant = {
      imports = [ ./vm.nix ];
    };
  };
}