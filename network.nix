{ config, pkgs, lib, pinned-pkgs, ... }:

let
  server_vars = (import ./server_vars.nix { pkgs = pkgs; pinned-pkgs = pinned-pkgs; });
  constants = (import ./constants.nix);
in rec
{
  services.openssh = {
    enable = true;
    # require public key authentication for better security
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "yes";
    settings.GatewayPorts = "clientspecified";
    ports = [ 22 2222 ]; # my uni wifi blocks port 22..
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
      https://${constants.mahmooz3_addr}/headscale {
        tls internal
        reverse_proxy localhost:8443
      }
      https://${constants.mahmooz3_addr}/grafana {
        tls internal
        reverse_proxy localhost:3000
      }
      http://${constants.mahmooz3_addr} {
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