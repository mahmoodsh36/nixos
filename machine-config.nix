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
           rev = "f4988204c3bb4dec1e9fb52bf876c178f989f9b7";
           sha256 = "sha256-J8IxayW8Gn/t0+YMmInV23cBE2qC+v51gTAlEEiHl4Q=";
         };
       });
  };
}