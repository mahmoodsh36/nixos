{ config, pkgs, lib, inputs, pkgs-pinned, ... }:

let
  server_vars = (import ./server_vars.nix { inherit pkgs; inherit inputs; inherit pkgs-pinned; });
  constants = (import ./constants.nix);
  mydomain = (if is_exit_node then constants.mydomain else "localhost");
  headscale_host = "headscale.${mydomain}";
  grafana_host = "grafana.${mydomain}";
  searxng_host = "search.${mydomain}";
  searxng_port = 8888;
  grafana_port = 3000;
  headscale_port = 8080;
  grafana_password_file = "/etc/nixos/grafana_password";
  is_exit_node = config.machine.name == "mahmooz3";
in rec
{
  imports = [
  ];

  networking = {
    hostName = config.machine.name;
    usePredictableInterfaceNames = true;
  };
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
    enable = is_exit_node;
    address = "0.0.0.0";
    settings = {
      server_url = "https://${headscale_host}";
      dns = {
        # override_local_dns = true;
        base_domain = "https://${mydomain}";
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
      "${searxng_host}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString searxng_port}
        '';
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      22 2222 # ssh
      80 # nginx - http
      443 # nginx - https
    ];
    enable = is_exit_node;
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
        domain = mydomain;
        root_url = grafana_host;
        serve_from_sub_path = true;
      };
    };
  };

  # to improve exit node performance
  services.networkd-dispatcher = lib.mkIf is_exit_node {
    enable = true;
    rules."50-tailscale" = {
      onState = ["routable"];
      script = ''
          IP=${lib.getExe pkgs.iproute2}
          IFACE=$($IP route | awk '/default/ {print $5}')
          [ -n "$IFACE" ] || IFACE="enp1s0"  # fallback
          ${lib.getExe pkgs.ethtool} -K "$IFACE" rx-udp-gro-forwarding on rx-gro-list off
        '';
    };
  };

  services.searx = {
    enable = true;
    redisCreateLocally = true;

    # rate limiting
    limiterSettings = {
      real_ip = {
        x_for = 1;
        ipv4_prefix = 32;
        ipv6_prefix = 56;
      };
      botdetection = {
        ip_limit = {
          filter_link_local = true;
          link_token = true;
        };
      };
    };

    # UWSGI configuration
    runInUwsgi = true;
    uwsgiConfig = {
      socket = "/run/searx/searx.sock";
      http = ":8888";
      chmod-socket = "660";
    };

    # searx configuration
    settings = {
      # instance settings
      general = {
        debug = false;
        instance_name = "mahmooz's searxng instance";
        donation_url = false;
        contact_url = false;
        privacypolicy_url = false;
        enable_metrics = false;
      };

      # user interface
      ui = {
        static_use_hash = true;
        default_locale = "en";
        query_in_title = true;
        infinite_scroll = false;
        center_alignment = true;
        default_theme = "simple";
        theme_args.simple_style = "auto";
        search_on_category_select = false;
        hotkeys = "vim";
      };

      # search engine settings
      search = {
        safe_search = 2;
        autocomplete_min = 2;
        autocomplete = "duckduckgo";
        ban_time_on_fail = 5;
        max_ban_time_on_fail = 120;
      };

      # server configuration
      server = {
        base_url = "http://${searxng_host}:${toString searxng_port}";
        port = searxng_port;
        bind_address = "0.0.0.0";
        secret_key = builtins.getEnv "SEARXNG_SECRET";
        limiter = true;
        public_instance = true;
        image_proxy = true;
        method = "GET";
      };

      # search engines
      engines = lib.mapAttrsToList (name: value: { inherit name; } // value) {
        "duckduckgo".disabled = false;
        "brave".disabled = true;
        "bing".disabled = false;
        "mojeek".disabled = true;
        "mwmbl".disabled = false;
        "mwmbl".weight = 0.4;
        "qwant".disabled = true;
        "crowdview".disabled = false;
        "crowdview".weight = 0.5;
        "curlie".disabled = true;
        "ddg definitions".disabled = false;
        "ddg definitions".weight = 2;
        "wikibooks".disabled = false;
        "wikidata".disabled = false;
        "wikiquote".disabled = true;
        "wikisource".disabled = true;
        "wikispecies".disabled = false;
        "wikispecies".weight = 0.5;
        "wikiversity".disabled = false;
        "wikiversity".weight = 0.5;
        "wikivoyage".disabled = false;
        "wikivoyage".weight = 0.5;
        "currency".disabled = true;
        "dictzone".disabled = true;
        "lingva".disabled = true;
        "bing images".disabled = false;
        "brave.images".disabled = true;
        "duckduckgo images".disabled = true;
        "google images".disabled = false;
        "qwant images".disabled = true;
        "1x".disabled = true;
        "artic".disabled = false;
        "deviantart".disabled = false;
        "flickr".disabled = true;
        "imgur".disabled = false;
        "library of congress".disabled = false;
        "material icons".disabled = true;
        "material icons".weight = 0.2;
        "openverse".disabled = false;
        "pinterest".disabled = true;
        "svgrepo".disabled = false;
        "unsplash".disabled = false;
        "wallhaven".disabled = false;
        "wikicommons.images".disabled = false;
        "yacy images".disabled = true;
        "bing videos".disabled = false;
        "brave.videos".disabled = true;
        "duckduckgo videos".disabled = true;
        "google videos".disabled = false;
        "qwant videos".disabled = false;
        "dailymotion".disabled = true;
        "google play movies".disabled = true;
        "invidious".disabled = true;
        "odysee".disabled = true;
        "peertube".disabled = false;
        "piped".disabled = true;
        "rumble".disabled = false;
        "sepiasearch".disabled = false;
        "vimeo".disabled = true;
        "youtube".disabled = false;
        "brave.news".disabled = true;
        "google news".disabled = true;
      };

      # outgoing requests
      outgoing = {
        request_timeout = 5.0;
        max_request_timeout = 15.0;
        pool_connections = 100;
        pool_maxsize = 15;
        enable_http2 = true;
      };

      # enabled plugins
      enabled_plugins = [
        "Basic Calculator"
        "Hash plugin"
        "Tor check plugin"
        "Open Access DOI rewrite"
        "Hostnames plugin"
        "Unit converter plugin"
        "Tracker URL remover"
      ];
    };
  };
}