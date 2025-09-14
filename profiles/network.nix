{ config, pkgs, lib, inputs, pkgs-pinned, myutils, ... }:

let
  server_vars = (import ../lib/server-vars.nix { inherit pkgs pkgs-pinned config inputs; });
  constants = (import ../lib/constants.nix);
  is_exit_node = config.machine.name == "mahmooz3";
  mydomain = (if is_exit_node then constants.mydomain else "0.0.0.0");
  headscale_host = "headscale.${mydomain}";
  grafana_host = "grafana.${mydomain}";
  searxng_host = "searx.${mydomain}";
  searxng_port = 8888;
  grafana_port = 3000;
  headscale_port = 8080;
  caddy_dir = "/var/www/mahmoodsh.com";
  caddy_log_dir = "/var/log/caddy";
  grafana_password = builtins.getEnv "GRAFANA_PASSWORD";
  searxng_secret = builtins.getEnv "SEARXNG_SECRET";
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

  services.prometheus = {
    enable = true;
    port = 9090; # default

    exporters = {
      node = {
        port = 9100;
        enabledCollectors = [ "systemd" ];
        enable = true;
      };
    };

    scrapeConfigs = [
      # scrape metrics from the node_exporter
      {
        job_name = "nodes";
        static_configs = [{
          targets = [
            "127.0.0.1:${toString config.services.prometheus.exporters.node.port}"
          ];
        }];
      }
      # scrape metrics from the Caddy web server
      {
        job_name = "caddy";
        static_configs = [{
          targets = [ "127.0.0.1:2019" ];
        }];
      }
    ];
  };

  services.caddy = {
    enable = true;
    globalConfig = ''
      # this option enables the caddy admin endpoint which prometheus needs.
      admin 127.0.0.1:2019
      metrics
    '';
    package = pkgs.caddy.withPlugins {
      plugins = ["github.com/mholt/caddy-ratelimit@v0.1.0"];
      hash = "sha256-81xohmYniQxit6ysAlBNZfSWU32JRvUlzMX5Sq0FDwY=";
    };
    # configure some reverse proxy traffic
    virtualHosts = {
      "https://${headscale_host}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString headscale_port}
        '';
      };
      "https://${grafana_host}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString grafana_port}
        '';
      };
      "https://${searxng_host}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString searxng_port}
        '';
      };
      "${mydomain}" = {
        extraConfig = ''
          log {
            output file ${caddy_log_dir}/access.log {
              roll_size 5000mib
              roll_keep 5000
              mode 0664
              #level info
            }
            format json
          }

          # enable compression for faster loading
          encode gzip zstd

          # security headers
          header {
            # tells browsers to always use https for a year
            Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
            # prevents clickjacking
            X-Frame-Options "SAMEORIGIN"
            # prevents content type sniffing
            X-Content-Type-Options "nosniff"
            # extra xss protection
            X-XSS-Protection "1; mode=block"
          }

          root * ${caddy_dir}
          file_server browse
        '';
      };
      "www.${mydomain}" = {
        extraConfig = "redir https://${mydomain}{uri} permanent";
      };
    };
  };
  # make caddy_dir owned by caddy:caddy
  systemd.tmpfiles.rules = [
    # create the directory if it doesn't exist
    # Type Path                  Mode    User   Group  Age Argument
    "d ${caddy_dir} 0755 caddy caddy - -"
    # recursively apply permissions to the directory and its contents
    # Type Path                  Mode  User   Group  Age Argument
    "z ${caddy_dir} - caddy caddy - -"
    # dir for caddy's access logs
    "d /var/log/caddy 0755 caddy caddy - -"
  ];

  # this service will collect logs sent by promtail.
  services.loki = {
    enable = true;
    configuration = {
      server = {
        http_listen_address = "127.0.0.1";
        http_listen_port = 3030;
        grpc_listen_port = null;
      };
      auth_enabled = false;

      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore = {
              store = "inmemory";
            };
            replication_factor = 1;
          };
          final_sleep = "0s";
        };
        chunk_idle_period = "1h";
        max_chunk_age = "1h";
        chunk_target_size = 99999999; # this seems to be in kilobytes?
        chunk_retain_period = "30s";
      };

      schema_config = {
        configs = [{
          from = "2025-05-05";
          store = "boltdb-shipper";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];
      };

      storage_config = {
        boltdb_shipper = {
          active_index_directory = "/var/lib/loki/boltdb-shipper-active";
          cache_location = "/var/lib/loki/boltdb-shipper-cache";
          cache_ttl = "24h";
        };

        filesystem = {
          directory = "/var/lib/loki/chunks";
        };
      };

      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
        allow_structured_metadata = false;
      };

      table_manager = {
        retention_deletes_enabled = false;
        retention_period = "0s";
      };

      compactor = {
        working_directory = "/var/lib/loki";
        compactor_ring = {
          kvstore = {
            store = "inmemory";
          };
        };
      };
    };
  };

  # this service watches the caddy log file and sends new entries to Loki.
  # even with this promtail stil throws permission denied errors? weird
  users.users.promtail.extraGroups = [ "caddy" ];
  services.promtail = {
    enable = true;
    configuration = {
      server.http_listen_port = 9080;
      clients = [
        # tells promtail where to send the logs.
        { url = "http://localhost:${toString config.services.loki.configuration.server.http_listen_port}/loki/api/v1/push"; }
      ];
      scrape_configs = [
        {
          job_name = "caddy";
          static_configs = [{
            targets = [ "localhost" ];
            labels = {
              __path__ = "${caddy_log_dir}/access*";
              job = "caddy";
              host = config.networking.hostName;
            };
          }];
        }
      ];
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

  services.grafana = lib.mkIf (grafana_password != "") {
    enable = is_exit_node;
    provision = {
      datasources = {
        settings = {
          datasources = [
            {
              name = "Loki";
              type = "loki";
              url = "http://localhost:${toString config.services.loki.configuration.server.http_listen_port}";
              access = "proxy";
              isDefault = true;
            }
            {
              name = "Prometheus";
              type = "prometheus";
              url = "http://localhost:${toString services.prometheus.port}";
              access = "proxy";
              isDefault = false;
            }
          ];
        };
      };
      dashboards.settings.providers = [
        {
          name = "Node Exporter Full";
          options.path = pkgs.fetchurl {
            name = "node-exporter-full-37-grafana-dashboard.json";
            url = "https://grafana.com/api/dashboards/1860/revisions/37/download";
            hash = "sha256-1DE1aaanRHHeCOMWDGdOS1wBXxOF84UXAjJzT5Ek6mM=";
          };
          orgId = 1;
        }
        # {
        #   name = "caddy";
        #   options.path = pkgs.fetchurl {
        #     name = "caddy.json";
        #     url = "https://grafana.com/api/dashboards/20802/revisions/1/download";
        #     hash = "sha256-vSt63PakGp5NzKFjbU5Yh0nDbKET5QRWp5nusM76/O4=";
        #   };
        #   orgId = 1;
        # }
      ];
    };
    settings = {
      # "auth.proxy" = {
      #   enabled = true;
      #   auto_sign_up = true;
      #   enable_login_token = false;
      # };
      # should we enable anonymous logins?
      # services.grafana.settings.auth.disable_login_form = true;
      # services.grafana.settings."auth.anonymous".enabled = true;
      # disable any auth except for admin
      users = {
        allow_sign_up = false;
        allow_org_create = false;
      };
      security = {
        admin_user = "mahmooz";
        admin_password = grafana_password;
        cookie_secure = true;
        cookie_samesite = "strict";
        content_security_policy = true;
      };
      server = {
        http_addr = "127.0.0.1";
        http_port = grafana_port;
        domain = mydomain;
        enable_gzip = true;
        # enforce_domain = true;
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


  services.searx = lib.mkIf (searxng_secret != "") {
    enable = true;
    redisCreateLocally = true;
    package = myutils.packageFromCommit {
      rev = "8eb28adfa3dc4de28e792e3bf49fcf9007ca8ac9";
      packageName = "searxng";
    };

    # rate limiting
    # limiterSettings = {
    #   real_ip = {
    #     x_for = 1;
    #     ipv4_prefix = 32;
    #     ipv6_prefix = 56;
    #   };
    #   botdetection = {
    #     ip_limit = {
    #       filter_link_local = true;
    #       link_token = true;
    #     };
    #   };
    # };

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
        safe_search = 0;
        autocomplete_min = 2;
        autocomplete = "duckduckgo";
        ban_time_on_fail = 5;
        max_ban_time_on_fail = 120;
        formats = ["html" "json"];
      };

      # server configuration
      server = {
        base_url = "http://${searxng_host}:${toString searxng_port}";
        port = searxng_port;
        bind_address = "127.0.0.1";
        secret_key = searxng_secret;
        limiter = false;
        public_instance = false;
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