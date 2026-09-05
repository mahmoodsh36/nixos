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
    ./profiles/desktop.nix
    ./profiles/home/home.nix
  ];

  config = {
    nixpkgs.overlays = [
      (final: prev: {
        nss_wrapper = prev.runCommand "nss_wrapper-stub" {} ''
          mkdir -p $out/lib $out/bin
        '';
      })
    ];
    _module.args = {
      inherit pkgs-unstable;
      inherit pkgs-pinned;
    };

    nixpkgs.config.allowUnfree = true;

    nix.package = pkgs.lixPackageSets.stable.lix;
  };
}