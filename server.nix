{ config, pkgs, lib, pinned-pkgs, ... }:

let
  server_vars = (import ./server_vars.nix { pkgs = pkgs; pinned-pkgs = pinned-pkgs; });
  constants = (import ./constants.nix);
in
{
  imports = [
    ./nvidia.nix
    ./network.nix
  ];

  boot.tmp.cleanOnBoot = true;
  system.etc.overlay.enable = false;
  time.timeZone = "Asia/Jerusalem";
  # power saving causes my internet to keep disconnecting
  powerManagement.enable = false;

  # use the systemd-boot EFI boot loader.
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;

  # use grub
  boot.loader.systemd-boot.enable = false;
  # boot.supportedFilesystems = [ "ntfs" ];
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    # useOSProber = false;
    device = "nodev";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # not needed with flakes and causes a bunch of warnings
  nix.channel.enable = false;

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
  programs.sniffnet.enable = true;
  programs.wireshark.enable = true;
  # services.atuin.enable = true;
  programs.dconf.enable = true;

  services.mysql = {
    enable = false;
    settings.mysqld.bind-address = "0.0.0.0";
  };

  # services.locate = {
  #   enable = true;
  #   interval = "hourly";
  # };

  # gpg
  services.pcscd.enable = true;
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = lib.mkForce pkgs.pinentry;
    enableSSHSupport = true;
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

  # self-hosted media service
  services.jellyfin = {
    enable = false;
    # openFirewall = true;
    user = "mahmooz"; # might need: sudo chown -R mahmooz:users /var/lib/jellyfin
    dataDir = "/home/mahmooz/.jellyfin";
  };

  # users
  users.users.mahmooz = {
    isNormalUser = true;
    extraGroups = [ "audio" "wheel" "docker" ];
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
  };

  # for binaries of nonfree packages, like pytorch (otherwise nix will try to compile them)
  nix.settings.substituters = [
    "https://nix-community.cachix.org"
    "https://cache.nixos.org/"
    "https://text-generation-inference.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    # compare to the key published at https://nix-community.org/cache
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "text-generation-inference.cachix.org-1:xdQ8eIf9LuIwS0n0/5ZmOHLaCXC6yy7MgzQNK/y+R1c="
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
      ConditionPathExists = "/home/mahmooz/work/scripts/keepalive.py";  # only run if script exists
    };
    wantedBy = [ "multi-user.target" ];
  };

  # garbage collection
  nix.settings.auto-optimise-store = true;
  # nix.gc = {
  #   automatic = true;
  #   dates = "weekly";
  #   options = "--delete-older-than 30d";
  # };

  system.stateVersion = "24.05"; # dont change
}