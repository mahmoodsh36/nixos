{ config, pkgs, lib, pinned-pkgs, ... }:

let
  server_vars = (import ./server_vars.nix { pkgs = pkgs; pinned-pkgs = pinned-pkgs; });
  per_machine_vars = (import ./per_machine_vars.nix {});
in
{
  imports = [
    ./hardware-configuration.nix # hardware scan results
  ];

  boot.tmp.cleanOnBoot = true;
  # use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.etc.overlay.enable = false;
  time.timeZone = "Asia/Jerusalem";
  # power saving causes my internet to keep disconnecting
  powerManagement.enable = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # not needed with flakes and causes a bunch of warnings
  nix.channel.enable = false;

  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  # networking
  networking = {
    hostName = "mahmooz";
    usePredictableInterfaceNames = true;
    useDHCP = false;
    networkmanager.enable = false;
    # block some hosts by redirecting to the loopback interface
    extraHosts = ''
      # 127.0.0.1 youtube.com
      # 127.0.0.1 www.youtube.com
      127.0.0.1 reddit.com
      127.0.0.1 www.reddit.com
      127.0.0.1 discord.com
      127.0.0.1 www.discord.com
      127.0.0.1 instagram.com
      127.0.0.1 www.instagram.com
      # 192.168.1.2 mahmooz2 # this prevents tailscale from identifying mahmooz2
      192.168.1.2 mahmooz2-2
    '';
  };

  # networkd config
  systemd.network.enable = true;
  services.resolved.enable = true;
  systemd.services."systemd-networkd".environment.SYSTEMD_LOG_LEVEL = "debug";
  # dont wait for interfaces to come online (faster boot)
  boot.initrd.systemd.network.wait-online.enable = false;
  systemd.network = {
    wait-online.enable = false;
    # static ip for wired ethernet
    networks."10-wired" = {
      matchConfig.Type = "ether"; # matches any wired interface
      DHCP = "no";
      address = [ "${per_machine_vars.static_ip}/24" ];
      # gateway = [ "192.168.1.1" ]; # setting a gateway messes up other connections
      linkConfig.RequiredForOnline = "routable";
    };
    # wireless interface (use DHCP)
    networks."20-wifi" = {
      matchConfig.Type = "wlan";
      DHCP = "yes"; # get IP dynamically
    };
  };
  # `iwd` for wifi management (alternative to wpa_supplicant)
  networking.wireless.iwd = {
    enable = true;
    settings = {
      General = {
        EnableNetworkConfiguration = true;
        EnablePowerSave = false;
      };
      Settings = {
        AutoConnect = true;
      };
    };
  };
  networking.firewall.enable = false;

  # enable some programs/services
  services.tailscale.enable = true;
  programs.mosh.enable = true;
  programs.zsh.enable = true;
  programs.adb.enable = true;
  services.mysql.package = pkgs.mariadb;
  programs.traceroute.enable = true;
  programs.direnv.enable = true;
  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    lfs.enable = true;
  };
  programs.htop.enable = true;
  programs.iotop.enable = true;
  programs.java.enable = true;
  programs.sniffnet.enable = true;
  programs.wireshark.enable = true;
  # services.atuin.enable = true;
  services.samba.enable = true;

  services.mysql = {
    enable = true;
    settings.mysqld.bind-address = "0.0.0.0";
  };

  # services.locate = {
  #   enable = true;
  #   interval = "hourly";
  # };

  services.openssh = {
    enable = true;
    # require public key authentication for better security
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "yes";
    settings.GatewayPorts = "clientspecified";
    ports = [ 22 80 443 2222 7422 ]; # my uni wifi blocks ssh.. maybe using 80 will help
  };
  users.users.mahmooz.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICQaNODbg0EX196+JkADTx/cB0arDn6FelMGsa0tD0p6 mahmooz@mahmooz"
  ];
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICQaNODbg0EX196+JkADTx/cB0arDn6FelMGsa0tD0p6 mahmooz@mahmooz"
  ];

  programs.nix-index = { # helps finding the package that contains a specific file
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };
  programs.command-not-found.enable = false; # needed for nix-index

  # gpg
  services.pcscd.enable = true;
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = lib.mkForce pkgs.pinentry;
    enableSSHSupport = true;
  };

  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    authentication = pkgs.lib.mkOverride 10 ''
      # generated file; do not edit!
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            trust
      host    all             all             ::1/128                 trust
      '';
    package = pkgs.postgresql_16;
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

  # services.mongodb.enable = true;

  # self-hosted media service
  services.jellyfin = {
    enable = false;
    # openFirewall = true;
    user = "mahmooz"; # might need: sudo chown -R mahmooz:users /var/lib/jellyfin
    dataDir = "/home/mahmooz/jellyfin";
  };

  # users
  users.users.mahmooz = {
    isNormalUser = true;
    extraGroups = [ "audio" "wheel" "docker" ];
    shell = pkgs.zsh;
    initialPassword = "123";
    packages = with pkgs; [
    ];
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
    PYTHON_HISTORY = "$HOME/brain/python_history";
    BRAIN_DIR = server_vars.brain_dir;
    MUSIC_DIR = server_vars.music_dir;
    WORK_DIR = server_vars.work_dir;
    NOTES_DIR = server_vars.notes_dir;
    SCRIPTS_DIR = server_vars.scripts_dir;
    DOTFILES_DIR = server_vars.dotfiles_dir;
    NIX_CONFIG_DIR = "$HOME/work/nixos/";
    BLOG_DIR = server_vars.blog_dir;
    # QT_SCALE_FACTOR = "2";
    EDITOR = "nvim";
    BROWSER = "firefox";
    LIB_PATH = "$HOME/mnt2/my/lib/:$HOME/mnt/vol1/lib/";
    MAIN_SERVER_IP = server_vars.main_server_ip;
    DATA_DIR = server_vars.data_dir;
    MPV_SOCKET_DIR = server_vars.mpv_socket_dir;
    MPV_MAIN_SOCKET_PATH = server_vars.mpv_main_socket_path;
    PERSONAL_WEBSITE = server_vars.personal_website;
    MYGITHUB = server_vars.mygithub;
  };

  # for binaries of nonfree packages, like pytorch (otherwise nix will try to compile them)
  nix.settings.substituters = [
    "https://nix-community.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    # compare to the key published at https://nix-community.org/cache
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];

  environment.systemPackages = server_vars.server_packages;
  nixpkgs.overlays = server_vars.server_overlays;

  # wheel group doesnt need password for sudo
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
    execWheelOnly = true;
  };

  systemd.services.keepalive = {
    description = "keep network connections alive";
    after = [ "network.target" ];
    wants = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3.withPackages (ps: with ps; [ aiohttp requests ])}/bin/python /home/mahmooz/work/scripts/keepalive.py";
      Restart = "always";
      RestartSec = 10;
      User = "mahmooz";
      NoNewPrivileges = true;
      ConditionPathExists = "/home/mahmooz/work/scripts/keepalive.py";  # only run if script exists
    };
    wantedBy = [ "multi-user.target" ];
  };

  system.stateVersion = "24.05"; # dont change
}