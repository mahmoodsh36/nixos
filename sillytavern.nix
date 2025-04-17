# /etc/nixos/configuration.nix
{ config, pkgs, lib, ... }:

let
  sillytavernDataPath = "/var/lib/sillytavern/data";
  sillytavernConfigPath = "/var/lib/sillytavern/config";
  sillytavernPluginsPath = "/var/lib/sillytavern/plugins";
  sillytavernExtensionsPath = "/var/lib/sillytavern/extensions";
  sillytavernPort = 8000;
  sillytavernVersion = "latest"; # pin to a specific tag like "1.11.4" for reproducibility
in
{
  config = lib.mkIf config.machine.is_desktop {
    virtualisation.oci-containers.containers.sillytavern = {
      image = "ghcr.io/sillytavern/sillytavern:${sillytavernVersion}";
      volumes = [
        "${sillytavernConfigPath}:/home/node/app/config:rw"
        "${sillytavernDataPath}:/home/node/app/data:rw"
        "${sillytavernExtensionsPath}:/home/node/app/public/scripts/extensions/third-party:rw"
        "${sillytavernPluginsPath}:/home/node/app/plugins:rw"
      ];
      extraOptions = [ "--pull=always" "--network=host" ];
    };

    # networking.firewall.allowedTCPPorts = [ sillytavernPort ];

    # ensure persistent directories exist (optional but recommended)
    systemd.tmpfiles.rules = [
      "d ${sillytavernDataPath} 0755 root root -"
      "d ${sillytavernConfigPath} 0755 root root -"
      "d ${sillytavernPluginsPath} 0755 root root -"
      "d ${sillytavernExtensionsPath} 0755 root root -"
    ];
  };
}