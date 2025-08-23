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

  config = {
    _module.args = { inherit pkgs-pinned; };

    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.cudaSupport = config.machine.enable_nvidia;
    nixpkgs.config.permittedInsecurePackages = [
      "ventoy-1.1.05"
    ];

    machine.llama-cpp.pkg =
      (if config.machine.enable_nvidia
       then inputs.llama-cpp-flake.packages.${pkgs.system}.cuda
       else inputs.llama-cpp-flake.packages.${pkgs.system}.default).overrideAttrs (_: {
         src = pkgs.fetchFromGitHub {
           owner = "pwilkin";
           repo = "llama.cpp";
           rev = "e8cbdad3d229d4ada2abd563d1a38030d438fe4c";
           sha256 = "sha256-CnDtcdvWQ1VVWLshD+MADhG5uFcZC969bYMzXc4OdCY=";
         };
       });
  };
}