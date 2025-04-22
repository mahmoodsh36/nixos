{ config, pkgs, lib, inputs, pkgs-pinned, ... }:

let
  pkgs-master = import inputs.pkgs-master {
    system = "x86_64-linux";
    config.allowUnfree = true;
    config.cudaSupport = config.machine.enable_nvidia;
  };
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
  _module.args = { inherit pkgs-pinned pkgs-master; }; # need to pass it to desktop.nix

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = config.machine.enable_nvidia;
}