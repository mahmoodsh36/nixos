{ config, pkgs, lib, pinned-pkgs, ... }:

let
  server_vars = (import ./server_vars.nix { pkgs = pkgs; pinned-pkgs = pinned-pkgs; });
  constants = (import ./constants.nix);
in rec
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
      # ${constants.mahmooz2_addr} mahmooz2 # this prevents tailscale from identifying mahmooz2
      ${constants.mahmooz2_addr} mahmooz2-2
      ${constants.mahmooz3_addr} mahmooz3
    '';
  };

  services.openssh = {
    enable = true;
    # require public key authentication for better security
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "yes";
    settings.GatewayPorts = "clientspecified";
    ports = [ 22 443 2222 ]; # my uni wifi blocks port 22..
  };
  users.users.mahmooz.openssh.authorizedKeys.keys = [
    constants.ssh_pub_key
  ];
  users.users.root.openssh.authorizedKeys.keys = [
    constants.ssh_pub_key
  ];
  programs.ssh.extraConfig = ''
    Host mahmooz2
        HostName ${constants.mahmooz2_addr}
        User     mahmooz
        IdentityFile       ~/brain/keys/hetzner1

    Host mahmooz2-2
        HostName ${constants.mahmooz2_addr}
        User     mahmooz
        IdentityFile       ~/brain/keys/hetzner1

    Host mahmooz3
        HostName ${constants.mahmooz3_addr}
        User     mahmooz
        IdentityFile       ~/brain/keys/hetzner1
  '';

  # networkd config
  systemd.network.enable = true;
  services.resolved.enable = true;
  systemd.services."systemd-networkd".environment.SYSTEMD_LOG_LEVEL = "debug";
  # dont wait for interfaces to come online (faster boot)
  boot.initrd.systemd.network.wait-online.enable = false;
  systemd.network = {
    wait-online.enable = false;
    # static ip for wired ethernet
    networks."10-wired" = (if config.machine.name != "mahmooz3" then {
      matchConfig.Type = "ether"; # matches any wired interface
      DHCP = "no";
      address = [ "${config.machine.static_ip}/24" ];
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

  # vpn/etc
  services.fail2ban.enable = true;
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    port = 12345; # (default: 41641)
    authKeyFile = "${constants.home_dir}/brain/keys/headscale1";
    extraUpFlags = [
      "--login-server=https://your-instance"
      "--accept-dns=false"
    ];
  };

  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 8443;
    serverUrl = "https://${constants.mahmooz3_addr}:8443";
    settings = {
      dns = {
        magic_dns = false;
      };
    };
  };

  services.caddy = {
    enable = true;
    # reverse proxy traffic to headscale
    configFile = pkgs.writeText "caddyfile" ''
      ${constants.mahmooz3_addr}/headscale:443 {
        tls internal
        reverse_proxy localhost:8443
      }
      ${constants.mahmooz3_addr}/grafana:443 {
        tls internal
        reverse_proxy localhost:3000
      }
      http://${constants.mahmooz3_addr}:80 {
        redir https://${constants.mahmooz3_addr}{uri}
      }
    '';
  };
  # allow the caddy user(and service) to edit certs
  services.tailscale.permitCertUid = "caddy";

  networking.firewall = {
    allowedTCPPorts = [ 22 80 443 2222 ];
    enable = true;
    allowedUDPPorts = [ services.tailscale.port ];
    trustedInterfaces = [ "tailscale0" ];
    checkReversePath = "loose"; # https://github.com/tailscale/tailscale/issues/4432#issuecomment-1112819111
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
        domain = "https://${constants.mahmooz3_addr}";
        root_url = "https://${constants.mahmooz3_addr}/grafana/";
        serve_from_sub_path = true;
      };
    };
  };
}