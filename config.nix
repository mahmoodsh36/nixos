{ config, pkgs, lib, inputs, system, ... }:

let
  pkgs-unstable = import inputs.pkgs-unstable {
    inherit system;
    config.allowUnfree = true;
    config.cudaSupport = config.machine.enable_nvidia;
  };
  pkgs-pinned = import inputs.pkgs-pinned {
    inherit system;
    config.allowUnfree = true;
    config.cudaSupport = config.machine.enable_nvidia;
  };
in
{
  imports = [
    ./modules/machine-options.nix
    ./profiles/machine-config.nix
    ./profiles/server.nix
    ./profiles/server-linux.nix
    ./profiles/desktop.nix
    ./profiles/desktop-linux.nix
    ./profiles/home/home.nix
    ./services/nixarr.nix
  ];

  config = {
    _module.args = {
      inherit pkgs-unstable;
      inherit pkgs-pinned;
    };

    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.cudaSupport = config.machine.enable_nvidia;
    nixpkgs.config.permittedInsecurePackages = [
      "ventoy-1.1.10"
    ];
  };
}