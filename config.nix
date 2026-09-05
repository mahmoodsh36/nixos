{ config, pkgs, lib, inputs, system, ... }:

let
  pkgs-unstable = import inputs.pkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
  pkgs-pinned = import inputs.pkgs-pinned {
    inherit system;
    config.allowUnfree = true;
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
    ./services/record.nix
  ];

  config = {
    _module.args = {
      inherit pkgs-unstable;
      inherit pkgs-pinned;
    };

    nixpkgs.config.allowUnfree = true;

    nix.package = pkgs.lixPackageSets.stable.lix;
  };
}