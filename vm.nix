{ config, pkgs, ... }:

{\n  imports =\n    [\n      ./profiles/server.nix\n    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "23.11";
}