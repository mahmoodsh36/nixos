{ config, pkgs, lib, inputs, ... }:

let
  pkgs-pinned = import inputs.pkgs-pinned {
    system = "x86_64-linux";
    config.allowUnfree = true;
    config.cudaSupport = config.machine.enable_nvidia;
  };
in
{
  imports = [
    ./modules/machine-options.nix
    ./profiles/machine-config.nix
    ./profiles/desktop.nix
    ./profiles/server.nix
    ./profiles/home/home.nix
  ];

  config = {
    _module.args = {
      inherit pkgs-pinned;
    };

    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.cudaSupport = config.machine.enable_nvidia;
    nixpkgs.config.permittedInsecurePackages = [
      "ventoy-1.1.07"
    ];
  };
}