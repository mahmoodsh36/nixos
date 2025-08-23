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
           rev = "920810a530ef0378b1957613e03f697738de03a4";
           sha256 = "sha256-A3tBZHF9VAcWcwV2m95oXziknx1FuE0Q5ACu9jV40p4=";
         };
       });
  };
}