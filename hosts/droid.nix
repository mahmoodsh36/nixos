{ config, lib, pkgs, ... }:

{
  environment.packages = with pkgs; [
    # essentials
    man git zsh findutils utillinux gnugrep gnused gnutar xz
    unixtools.top unixtools.ping procps openssh

    # tools i need
    neovim emacs
    rsync
    # (sbcl.withPackages (ps: with ps; [
    #   cl-ppcre str
    #   cl-fad
    #   clingon # command-line options parser
    #   ironclad # crypto functions
    # ]))
  ];

  # enable some fancy/useful stuff
  android-integration = {
    termux-open.enable = true;
    termux-open-url.enable = true;
    xdg-open.enable = true;
    termux-reload-settings.enable = true;
    termux-setup-storage.enable = true;
    termux-wake-lock.enable = true;
    termux-wake-unlock.enable = true;
    unsupported.enable = true;
    am.enable = true;
  };

  user = {
    userName = "mahmooz";
    shell = "${pkgs.zsh}/bin/zsh";
  };

  home-manager = {
    backupFileExtension = "hm-bak";
    useUserPackages = true;
    useGlobalPkgs = true;

    config =
      { config, lib, pkgs, ... }:
      {
        home.stateVersion = "24.05";
      };
  };

  environment.sessionVariables.BRAIN_DIR = "/sdcard/brain";

  nix.extraOptions = ''
    experimental-features = ${
      builtins.concatStringsSep " " [
        "nix-command"
        "flakes"
      ]
    }
    builders-use-substitutes = true
  '';
  nix.package = pkgs.nixVersions.latest;

  environment.etcBackupExtension = ".bak";
  time.timeZone = "Asia/Jerusalem";
  system.stateVersion = "24.05";
}