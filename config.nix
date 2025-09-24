{ config, pkgs, lib, inputs, ... }:

let
  pkgs-master = import inputs.pkgs-master {
    system = "x86_64-linux";
    config.allowUnfree = true;
    config.cudaSupport = config.machine.enable_nvidia;
  };
  pkgs-unstable = import inputs.pkgs-unstable {
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
      inherit pkgs-master;
      inherit pkgs-unstable;
    };

    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.cudaSupport = config.machine.enable_nvidia;
    nixpkgs.config.permittedInsecurePackages = [
      "ventoy-1.1.07"
    ];
  };
}