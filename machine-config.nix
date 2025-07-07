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
    ./desktop.nix
    ./server.nix
  ];
  _module.args = { inherit pkgs-pinned; };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = config.machine.enable_nvidia;
}