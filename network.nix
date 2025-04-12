{ config, pkgs, lib, pinned-pkgs, ... }:

let
  server_vars = (import ./server_vars.nix { pkgs = pkgs; pinned-pkgs = pinned-pkgs; });
  constants = (import ./constants.nix);
  headscale_host = "headscale.${constants.mydomain}";
  grafana_host = "grafana.${constants.mydomain}";
  grafana_port = 3000;
  headscale_port = 8080;
  grafana_password_file = "/etc/nixos/grafana_password";
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
  };


  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    settings = {
      server_url = "https://${headscale_host}";
      dns = {
        # override_local_dns = true;
        base_domain = "https://${constants.mydomain}";
        # magic_dns = true;
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
    virtualHosts = {
      "${headscale_host}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString headscale_port}
        '';
      };
      "http://${constants.mydomain}" = {
        extraConfig = "redir https://${constants.mydomain}{uri} permanent";
      };
      "${grafana_host}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString grafana_port}
        '';
      };
    };
  };

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

  services.grafana = lib.mkIf (builtins.pathExists grafana_password_file) {
    enable = true;
    settings = {
      security = {
        admin_user = "mahmooz";
        admin_password = "$__file{${grafana_password_file}}";
        cookie_secure = true;
        cookie_samesite = "strict";
        content_security_policy = true;
      };
      server = {
        http_addr = "0.0.0.0";
        http_port = grafana_port;
        domain = constants.mydomain;
        root_url = grafana_host;
        serve_from_sub_path = true;
      };
    };
  };
}