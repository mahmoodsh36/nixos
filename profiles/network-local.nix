{ config, pkgs, lib, ... }:

let
  constants = (import ../lib/constants.nix);
in
{
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  # networking
  networking = {
    useDHCP = false;
    networkmanager.enable = false;
    # block some hosts by redirecting to the loopback interface
    extraHosts = ''
      127.0.0.1 youtube.com
      127.0.0.1 www.youtube.com
      127.0.0.1 reddit.com
      127.0.0.1 www.reddit.com
      127.0.0.1 discord.com
      127.0.0.1 www.discord.com
      127.0.0.1 instagram.com
      127.0.0.1 www.instagram.com
      ${constants.mahmooz2_addr} mahmooz2-2
      ${constants.mahmooz1_addr} mahmooz1-2
      ${constants.mahmooz3_addr} mahmooz3
    '';
  };

  # networkd config
  systemd.network.enable = true;
  services.resolved.enable = true;
  systemd.services."systemd-networkd".environment.SYSTEMD_LOG_LEVEL = "debug";
  # dont wait for interfaces to come online (faster boot)
  boot.initrd.systemd.network.wait-online.enable = false;
  systemd.network = {
    wait-online.enable = false;
    # static ip for wired ethernet
    networks."10-wired" = {
      matchConfig.Type = "ether"; # matches any wired interface
      DHCP = "no";
      address = [ "${config.machine.static_ip}/24" ];
      # gateway = [ "192.168.1.1" ]; # setting a gateway messes up other connections
      linkConfig.RequiredForOnline = "routable";
    };
    # wireless interface (use DHCP)
    networks."20-wifi" = {
      matchConfig.Type = "wlan";
      DHCP = "yes"; # get IP dynamically
    };
  };
  # `iwd` for wifi management (alternative to wpa_supplicant)
  networking.wireless.iwd = {
    enable = true;
    settings = {
      General = {
        EnableNetworkConfiguration = true;
        EnablePowerSave = false;
      };
      Settings = {
        AutoConnect = true;
      };
    };
  };
}