{ config, pkgs, lib, ... }:

let
  server_vars = (import ./server_vars.nix { pkgs = pkgs; });
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
  # what about this? works for hetzner
  # boot.loader.grub.device = "nodev";

  nixpkgs.config.allowUnfree = true;
  time.timeZone = "Asia/Jerusalem";
  system.etc.overlay.enable = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # do we even need this?
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  # networking
  networking = {
    hostName = "mahmooz";
    # resolvconf.dnsExtensionMechanism = false;
    networkmanager.enable = true;
    # block some hosts by redirecting to the loopback interface
    extraHosts = ''
      127.0.0.1 youtube.com
      127.0.0.1 www.youtube.com
      # 127.0.0.1 reddit.com
      # 127.0.0.1 www.reddit.com
      127.0.0.1 discord.com
      127.0.0.1 www.discord.com
      127.0.0.1 instagram.com
      127.0.0.1 www.instagram.com
    '';
  };

  services.tailscale.enable = true;

  # enable some programs/services
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
  programs.nix-ld.enable = true;
  programs.sniffnet.enable = true;
  programs.wireshark.enable = true;
  # services.atuin.enable = true;
  services.samba.enable = true;

  services.mysql = {
    enable = true;
    settings.mysqld.bind-address = "0.0.0.0";
  };

  services.locate = {
    enable = true;
    interval = "hourly";
  };

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
    enable = true;
    # openFirewall = true;
    user = "mahmooz"; # might need: sudo chown -R mahmooz:users /var/lib/jellyfin
    dataDir = "/home/mahmooz/jellyfin";
  };

  # users
  users.users.mahmooz = {
    isNormalUser = true;
    extraGroups = [ "audio" "wheel" ];
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

  # not needed with flakes and causes a bunch of warnings
  nix.channel.enable = false;

  # for binaries of nonfree packages, like pytorch (otherwise nix will try to compile them)
  nix.settings.substituters = [
    "https://nix-community.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    # Compare to the key published at https://nix-community.org/cache
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

  services.llama-cpp = {
    enable = per_machine_vars.enable_nvidia;
    model = "/home/mahmooz/models/models--Qwen--Qwen2.5-Coder-14B-Instruct";
    extraFlags = ["-fa" "-ngl" "35" "-p" "you are a computer expert and a great programmer and mathematician" "--host" "0.0.0.0"];
    host = "0.0.0.0";
  };
  systemd.services.llama-cpp.serviceConfig.user = "mahmooz";

  system.stateVersion = "24.05"; # dont change
}
