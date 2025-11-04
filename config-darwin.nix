{ config, pkgs, lib, inputs, system, ... }:

let
  pkgs-master = import inputs.pkgs-master {
    inherit system;
    config.allowUnfree = true;
    config.cudaSupport = config.machine.enable_nvidia;
  };
  pkgs-unstable = import inputs.pkgs-unstable {
    inherit system;
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
    # this is always gonna be false anyway on mac
    nixpkgs.config.cudaSupport = config.machine.enable_nvidia;
    nixpkgs.config.permittedInsecurePackages = [
      "ventoy-1.1.07"
    ];
  };
}
