{ config, pkgs, lib, inputs, ... }:

{
  config = {
    machine.llama-cpp.pkg =
      (if config.machine.enable_nvidia
       then inputs.llama-cpp-flake.packages.${pkgs.system}.cuda
       else inputs.llama-cpp-flake.packages.${pkgs.system}.default);
  };
}