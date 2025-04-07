{ config, pkgs, lib, pinned-pkgs, ... }:

let
  per_machine_vars = (import ./per_machine_vars.nix {});
in
{
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  # networking
  networking = {
    hostName = "mahmooz";
    usePredictableInterfaceNames = true;
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
      # 192.168.1.2 mahmooz2 # this prevents tailscale from identifying mahmooz2
      192.168.1.2 mahmooz2-2
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
    networks."10-wired" = (if per_machine_vars.machine_name != "mahmooz3" then {
      matchConfig.Type = "ether"; # matches any wired interface
      DHCP = "no";
      address = [ "${per_machine_vars.static_ip}/24" ];
      # gateway = [ "192.168.1.1" ]; # setting a gateway messes up other connections
      linkConfig.RequiredForOnline = "routable";
    } else {
      # keep default behavior
    });
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
  networking.firewall.enable = false;
}