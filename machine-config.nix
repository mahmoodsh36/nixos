{ config, pkgs, lib, inputs, pinned-pkgs, ... }:

{
  imports = [
    ./desktop.nix
    ./server.nix
  ];
  _module.args = { inherit pinned-pkgs; }; # need to pass it to desktop.nix

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = config.machine.enable_nvidia;
}