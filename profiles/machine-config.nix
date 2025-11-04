{ config, pkgs, lib, inputs, ... }:

{
  config = {
    machine.llama-cpp.pkg = pkgs.llama-cpp;
    # (if config.machine.enable_nvidia
    #  then inputs.llama-cpp-flake.packages.${pkgs.system}.cuda
    #  else inputs.llama-cpp-flake.packages.${pkgs.system}.default);
    machine.voldir = if config.machine.is_darwin
                     then "/Volumes/main"
                     else "/home/${config.machine.user}";
  };
}
