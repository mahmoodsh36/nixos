{ config, pkgs, lib, inputs, ... }:

# three long-running units:
# - trackify-web     : gunicorn wsgi app (reverse-proxied by caddy)
# - trackify-tracker : polls the spotify api and records plays
# - trackify-cache   : warms the redis "top users" cache
# backed by a local mariadb + redis.

let
  constants = import ../lib/constants.nix;
  cfg = config.services.trackify;

  domain = "trackify.${constants.mydomain}";
  port = 8091; # gunicorn bind port (loopback only, caddy proxies to it)

  # local loopback-only db creds. mariadb binds to 127.0.0.1 and the port isnt firewalled open,
  # so these guard nothing beyond the machine itself. safe to inline.
  dbName = "trackify";
  dbUser = "trackify";
  dbPass = "trackify";

  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    flask
    requests
    redis
    gunicorn
    mysql-connector
  ]);

  # secrets come from the build-time environment: source env.sh before running
  secret = name: builtins.toJSON (builtins.getEnv name);

  # nix-generated config.py: non-secret settings inline, secrets baked in from
  # the environment. replaces the config.py that ships in the repo.
  configPy = pkgs.writeText "config.py" ''
    CONFIG = {
        'database': '${dbName}',
        'database_user': '${dbUser}',
        'database_password': '${dbPass}',
        'database_host': '127.0.0.1',
        'secret_key': ${secret "TRACKIFY_SECRET_KEY"},
        'client_id': ${secret "TRACKIFY_SPOTIFY_CLIENT_ID"},
        'client_secret': ${secret "TRACKIFY_SPOTIFY_CLIENT_SECRET"},
        'scope': "user-library-read playlist-read-private user-read-playback-state user-read-currently-playing user-modify-playback-state",
        'redirect_uri': "https://${domain}/spotify/callback",
        'permanent_session': True,
        'discogs_api_key': ${secret "TRACKIFY_DISCOGS_API_KEY"},
        'discogs_api_secret': ${secret "TRACKIFY_DISCOGS_API_SECRET"},
    }
    CONFIG_UPPERCASE = {}
    for key, value in CONFIG.items():
        CONFIG_UPPERCASE[key.upper()] = value
  '';

  # app source (github flake input) with our config.py dropped in. the app does
  # a bare `import config`, so config.py must sit next to the trackify package
  # and that dir must be the cwd / on sys.path.
  appDir = pkgs.runCommand "trackify-src" { } ''
    cp -r ${inputs.trackify} $out
    chmod -R u+w $out
    cp ${configPy} $out/config.py
  '';

  # shared bits for the three long-running units.
  commonServiceConfig = {
    Type = "simple";
    DynamicUser = true;
    WorkingDirectory = appDir;
    Restart = "always";
    RestartSec = "5s";
  };

  redisUnit = "redis-trackify.service";
in
{
  options.services.trackify.enable =
    lib.mkEnableOption "trackify spotify tracker + web app";

  config = lib.mkIf cfg.enable {
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      settings.mysqld.bind-address = "127.0.0.1";
    };

    services.redis.servers.trackify = {
      enable = true;
      bind = "127.0.0.1";
      port = 6379; # the app hardcodes localhost:6379
    };

    # one-shot db bootstrap: create db/user, load schema (idempotent)
    systemd.services.trackify-db-init = {
      description = "initialize the trackify database";
      after = [ "mysql.service" ];
      requires = [ "mysql.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      # runs as root -> can auth to mariadb's root@localhost over the unix socket
      script = ''
        ${pkgs.mariadb}/bin/mysql <<'SQL'
        CREATE DATABASE IF NOT EXISTS ${dbName} CHARACTER SET utf8mb4;
        CREATE USER IF NOT EXISTS '${dbUser}'@'localhost' IDENTIFIED BY '${dbPass}';
        CREATE USER IF NOT EXISTS '${dbUser}'@'127.0.0.1' IDENTIFIED BY '${dbPass}';
        GRANT ALL PRIVILEGES ON ${dbName}.* TO '${dbUser}'@'localhost';
        GRANT ALL PRIVILEGES ON ${dbName}.* TO '${dbUser}'@'127.0.0.1';
        FLUSH PRIVILEGES;
        SQL
        ${pkgs.mariadb}/bin/mysql ${dbName} < ${appDir}/trackify/db/schema.sql
      '';
    };

    # web app (gunicorn)
    systemd.services.trackify-web = {
      description = "trackify web app (gunicorn)";
      after = [ "trackify-db-init.service" redisUnit "network.target" ];
      requires = [ "trackify-db-init.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = commonServiceConfig // {
        ExecStart = "${pythonEnv}/bin/gunicorn --workers 2 --bind 127.0.0.1:${toString port} trackify.webapp:web_application";
      };
    };

    # spotify tracker daemon
    systemd.services.trackify-tracker = {
      description = "trackify spotify tracker daemon";
      after = [ "trackify-db-init.service" "network.target" ];
      requires = [ "trackify-db-init.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = commonServiceConfig // {
        ExecStart = "${pythonEnv}/bin/python -m trackify.spotify.tracker";
      };
    };

    # redis cache-warming daemon
    systemd.services.trackify-cache = {
      description = "trackify cache-warming daemon";
      after = [ "trackify-db-init.service" redisUnit "network.target" ];
      requires = [ "trackify-db-init.service" redisUnit ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = commonServiceConfig // {
        ExecStart = "${pythonEnv}/bin/python -m trackify.cache.daemon";
      };
    };

    # reverse proxy (caddy is already enabled on the exit node)
    services.caddy.virtualHosts."${domain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString port}
      '';
    };
  };
}
