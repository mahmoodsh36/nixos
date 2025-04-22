{ config, pkgs, lib, inputs, pkgs-pinned, ... }:

{
  imports = [
    ./desktop.nix
    ./server.nix
  ];
  _module.args = { inherit pkgs-pinned; }; # need to pass it to desktop.nix

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = config.machine.enable_nvidia;
}