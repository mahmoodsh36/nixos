{ config, pkgs, lib, ... }:

let
  cfg = config.services.ghost-blog;

  # secrets come from env.sh, which upgrade.sh sources (same pattern as network.nix)
  smtp_host = builtins.getEnv "GHOST_SMTP_HOST";
  smtp_user = builtins.getEnv "GHOST_SMTP_USER";
  smtp_pass = builtins.getEnv "GHOST_SMTP_PASSWORD";

  mail_env = lib.optionalAttrs (smtp_host != "") {
    mail__transport = "SMTP";
    mail__options__host = smtp_host;
    mail__options__port = toString cfg.smtpPort;
    mail__options__secure = if cfg.smtpPort == 465 then "true" else "false";
    mail__options__auth__user = smtp_user;
    mail__options__auth__pass = smtp_pass;
    mail__from = cfg.fromAddress;
  };

  network = "ghost";
  pod = "ghost-pod";
in
{
  options.services.ghost-blog = {
    enable = lib.mkEnableOption "self-hosted ghost blog" // {
      default = config.machine.name == "mahmooz3";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "dinagrey.com";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2368;
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ghost";
    };

    backupDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/backup/ghost";
    };

    fromAddress = lib.mkOption {
      type = lib.types.str;
      default = "noreply@${cfg.domain}";
    };

    smtpPort = lib.mkOption {
      type = lib.types.port;
      default = 587;
    };

    dbPassword = lib.mkOption {
      type = lib.types.str;
      default = builtins.getEnv "GHOST_DB_PASSWORD";
    };

    # claims the owner account on first boot, otherwise whoever finds /ghost
    # first can claim it
    owner = {
      name = lib.mkOption {
        type = lib.types.str;
        default = let n = builtins.getEnv "GHOST_ADMIN_NAME"; in
          if n != "" then n else "admin";
      };
      email = lib.mkOption {
        type = lib.types.str;
        default = builtins.getEnv "GHOST_ADMIN_EMAIL";
      };
      password = lib.mkOption {
        type = lib.types.str;
        default = builtins.getEnv "GHOST_ADMIN_PASSWORD";
      };
    };

    siteTitle = lib.mkOption {
      type = lib.types.str;
      default = let t = builtins.getEnv "GHOST_SITE_TITLE"; in
        if t != "" then t else "blog";
    };

    # pinned rather than :6 so a rebuild never silently jumps a minor version
    ghostImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/library/ghost:6.56-alpine";
    };

    mysqlImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/library/mysql:8.4";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = cfg.dbPassword != "";
      message = "services.ghost-blog: set GHOST_DB_PASSWORD in env.sh";
    }];

    # podman is gated off on low_resources hosts in server-linux.nix
    virtualisation.podman.enable = lib.mkForce true;
    virtualisation.oci-containers.backend = "podman";

    virtualisation.oci-containers.containers = {
      ghost-db = {
        image = cfg.mysqlImage;
        volumes = [ "${cfg.dataDir}/mysql:/var/lib/mysql" ];
        environment = {
          MYSQL_DATABASE = "ghost";
          MYSQL_USER = "ghost";
          MYSQL_PASSWORD = cfg.dbPassword;
          MYSQL_RANDOM_ROOT_PASSWORD = "yes";
        };
        # defaults assume a db-dedicated box, this one has ~1.5g free
        cmd = [
          "--innodb-buffer-pool-size=128M"
          "--performance-schema=OFF"
        ];
        extraOptions = [ "--pod=${pod}" ];
      };

      ghost = {
        image = cfg.ghostImage;
        dependsOn = [ "ghost-db" ];
        # the pod publishes the port, a container in a pod cannot
        volumes = [ "${cfg.dataDir}/content:/var/lib/ghost/content" ];
        environment = {
          url = "https://${cfg.domain}";
          NODE_ENV = "production";
          database__client = "mysql";
          # same pod, so mysql is reachable on loopback and needs no container dns
          database__connection__host = "127.0.0.1";
          database__connection__user = "ghost";
          database__connection__password = cfg.dbPassword;
          database__connection__database = "ghost";
          # ghost emails a code when staff sign in from a new device, so leaving
          # this on without smtp locks them out
          security__staffDeviceVerification =
            if smtp_host != "" then "true" else "false";
        } // mail_env;
        extraOptions = [ "--pod=${pod}" ];
      };
    };

    # oci-containers creates neither networks nor pods itself.
    # dns is off because blocky owns *:53 and aardvark-dns cannot then bind the
    # bridge gateway. the containers share a pod, so they reach each other on
    # loopback and never need it.
    systemd.services."podman-network-${network}" = {
      path = [ config.virtualisation.podman.package ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if ! podman network exists ${network} \
           || [ "$(podman network inspect ${network} --format '{{.DNSEnabled}}')" != "false" ]; then
          podman network rm -f ${network} || true
          podman network create --disable-dns ${network}
        fi
      '';
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services."podman-pod-${pod}" = {
      path = [ config.virtualisation.podman.package ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      after = [ "podman-network-${network}.service" ];
      requires = [ "podman-network-${network}.service" ];
      # caddy terminates tls, so only bind loopback
      script = ''
        podman pod exists ${pod} \
          || podman pod create --name ${pod} --network ${network} \
               --publish 127.0.0.1:${toString cfg.port}:2368
      '';
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.podman-ghost = {
      after = [ "podman-pod-${pod}.service" ];
      requires = [ "podman-pod-${pod}.service" ];
    };
    systemd.services.podman-ghost-db = {
      after = [ "podman-pod-${pod}.service" ];
      requires = [ "podman-pod-${pod}.service" ];
    };

    # uids match the ones the upstream images run as (ghost: node/1000, mysql: 999)
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root - -"
      "d ${cfg.dataDir}/content 0755 1000 1000 - -"
      "d ${cfg.dataDir}/mysql 0700 999 999 - -"
      "d ${cfg.backupDir} 0700 root root - -"
    ];

    services.caddy.virtualHosts."https://${cfg.domain}" = {
      extraConfig = ''
        encode gzip zstd

        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          Referrer-Policy "strict-origin-when-cross-origin"
        }

        reverse_proxy 127.0.0.1:${toString cfg.port}
      '';
    };

    services.caddy.virtualHosts."www.${cfg.domain}" = {
      extraConfig = "redir https://${cfg.domain}{uri} permanent";
    };

    # the setup endpoint is unauthenticated until it succeeds once, so claim the
    # owner as soon as ghost is up rather than leaving the window open
    systemd.services.ghost-setup = lib.mkIf (cfg.owner.email != "" && cfg.owner.password != "") {
      after = [ "podman-ghost.service" ];
      requires = [ "podman-ghost.service" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ curl jq coreutils ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        api=http://127.0.0.1:${toString cfg.port}/ghost/api/admin/authentication/setup/

        for i in $(seq 1 60); do
          curl -sf -m 5 "$api" >/dev/null 2>&1 && break
          sleep 5
        done

        if curl -sf -m 10 "$api" | jq -e '.setup[0].status == true' >/dev/null; then
          echo "owner already claimed"
          exit 0
        fi

        jq -n \
          --arg name ${lib.escapeShellArg cfg.owner.name} \
          --arg email ${lib.escapeShellArg cfg.owner.email} \
          --arg password ${lib.escapeShellArg cfg.owner.password} \
          --arg blogTitle ${lib.escapeShellArg cfg.siteTitle} \
          '{setup:[{name:$name,email:$email,password:$password,blogTitle:$blogTitle}]}' \
          | curl -sf -m 30 -X POST "$api" \
              -H 'Content-Type: application/json' \
              -H 'Accept-Version: v5.0' \
              --data @- >/dev/null \
          && echo "claimed owner ${cfg.owner.email}"
      '';
    };

    # the db holds the posts, content/ holds the uploads, both are needed to restore
    systemd.services.ghost-backup = {
      path = with pkgs; [ config.virtualisation.podman.package gzip gnutar findutils coreutils ];
      serviceConfig.Type = "oneshot";
      script = ''
        ts=$(date +%F)
        podman exec ghost-db mysqldump \
          --user=ghost --password='${cfg.dbPassword}' --single-transaction ghost \
          | gzip > ${cfg.backupDir}/db-$ts.sql.gz
        tar czf ${cfg.backupDir}/content-$ts.tar.gz -C ${cfg.dataDir} content
        find ${cfg.backupDir} -type f -mtime +14 -delete
      '';
    };

    systemd.timers.ghost-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}
