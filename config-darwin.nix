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
    ./profiles/desktop.nix
    ./profiles/home/home.nix
  ];

  config = {
    nixpkgs.overlays = [
      # mailutils 3.21 fails to link the uidnew sieve module on darwin
      # (undefined _mu_url_* symbols); 3.19 from pkgs-pinned is fine
      (final: prev: {
        mailutils = pkgs-pinned.mailutils;
      })
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
    # this is always gonna be false anyway on mac
    nixpkgs.config.cudaSupport = config.machine.enable_nvidia;
    nixpkgs.config.permittedInsecurePackages = [
      "ventoy-1.1.12"
    ];
  };
}