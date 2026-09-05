{ config, pkgs, lib, inputs, ... }:

{
  config = {
    machine.voldir = if config.machine.is_darwin
                     then "/Volumes/main"
                     else "/home/${config.machine.user}";
  };
}