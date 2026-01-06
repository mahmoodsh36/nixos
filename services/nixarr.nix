{ config, pkgs, lib, ... }:

{
  nixarr = {
    enable = config.machine.is_home_server;

    mediaDir = "${config.machine.datadir}/media";
    stateDir = "${config.machine.datadir}/.state/nixarr";

    jellyfin.enable = false;

    radarr = {
      enable = true;
      openFirewall = true;
    };

    sonarr = {
      enable = true;
      openFirewall = true;
    };

    bazarr = {
      enable = true;
      openFirewall = true;
    };

    prowlarr = {
      enable = true;
      openFirewall = true;
    };
  };
}
