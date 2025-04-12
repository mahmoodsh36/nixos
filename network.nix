{ config, pkgs, lib, pinned-pkgs, ... }:

let
  server_vars = (import ./server_vars.nix { pkgs = pkgs; pinned-pkgs = pinned-pkgs; });
  constants = (import ./constants.nix);
  private_domain = "mahmooz3.lan";
  headscale_host = "headscale.${private_domain}";
  grafana_host = "grafana.${private_domain}";
  grafana_port = 3000;
  headscale_port = 8443;
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
  };


  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    # port = 8443;
    settings = {
      server_url = "https://${headscale_host}:${toString headscale_port}";
      dns = {
        # override_local_dns = true;
        base_domain = private_domain;
        magic_dns = true;
        # domains = [ headscale_host ];
        nameservers.global = [
          "1.1.1.1" # cloudflare
          "9.9.9.9" # quad9
        ];
      };
    };
  };

  services.caddy = {
    enable = true;
    # configure some reverse proxy traffic
    # allow connection via public ip?
    virtualHosts."grafana.${constants.mahmooz3_addr}" = {
       extraConfig = ''
         redir https://${grafana_host}{uri} permanent
       '';
    };
    # for machines that are part of the tailnet
    virtualHosts."${headscale_host}" = {
      extraConfig = ''
        tls internal
        reverse_proxy localhost:${toString headscale_port}
      '';
    };
    virtualHosts."${grafana_host}" = {
      extraConfig = ''
        tls internal
        reverse_proxy localhost:${toString grafana_port}
      '';
    };
  };
  # allow the caddy user(and service) to edit certs
  services.tailscale.permitCertUid = "caddy";

  networking.firewall = {
    allowedTCPPorts = [
      22 2222 # ssh
      80 # caddy - http
      443 # caddy - https
    ];
    enable = true;
    allowedUDPPorts = [ services.tailscale.port ];
    trustedInterfaces = [ config.services.tailscale.interfaceName ];
    checkReversePath = "loose"; # https://github.com/tailscale/tailscale/issues/4432#issuecomment-1112819111
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = grafana_port;
        domain = private_domain;
        root_url = grafana_host;
        serve_from_sub_path = true;
      };
    };
  };
}