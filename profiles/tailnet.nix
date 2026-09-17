{ config, pkgs, lib, options, system, ... }:

let
  constants = (import ../lib/constants.nix);
  isLinux = options ? boot.kernelPackages;
  isDarwin = lib.strings.hasInfix "darwin" system;
  is_exit_node = config.machine.name == "mahmooz3";
  # mydomain is "localhost" off the exit node, so clients use the public host.
  headscale_public_host = "headscale.${constants.mydomain}";
  # full key format: hskey-auth-<12>-<64>. empty means manual tailscale join.
  headscale_authkey = builtins.getEnv "HEADSCALE_PREAUTH_KEY";
  have_headscale_key = headscale_authkey != "";
in
{
  config = lib.mkMerge ([]
    ++ (lib.optional isDarwin {
      services.tailscale = {
        enable = true;
        overrideLocalDns = true;
      };
    })
    ++ (lib.optional isLinux {
      services.tailscale = lib.mkIf (!config.machine.is_vm) {
        enable = true;
        useRoutingFeatures = "both";
        port = 12345; # (default: 41641)
        # without the key, join manually: tailscale up --login-server=https://headscale.mahmoodsh.com
        authKeyFile = lib.mkIf have_headscale_key "/etc/tailscale-preauthkey";
        extraUpFlags = lib.mkIf have_headscale_key [ "--login-server=https://${headscale_public_host}" ];
      };

      environment.etc."tailscale-preauthkey" = lib.mkIf have_headscale_key {
        text = headscale_authkey;
        mode = "0600";
      };

      services.headscale = {
        enable = is_exit_node && have_headscale_key;
        address = "0.0.0.0";
        settings = {
          server_url = "https://${headscale_public_host}";
          dns = {
            base_domain = "tailnet.${constants.mydomain}";
            magic_dns = true;
            nameservers.global = [
              "127.0.0.1:${toString constants.blocky_port}"
            ];
          };
        };
      };

      # headscale takes no key material as config, so pin the env key directly
      # (prefix + bcrypt). breaks if upstream changes the pre_auth_keys schema.
      # reruns when the key changes; retries on failure for slow headscale.
      systemd.services.headscale-setup = lib.mkIf (is_exit_node && have_headscale_key) {
        description = "pin declarative headscale preauth key from env.sh";
        wantedBy = [ "multi-user.target" ];
        after = [ "headscale.service" ];
        wants = [ "headscale.service" ];
        restartTriggers = [ headscale_authkey ];
        path = with pkgs; [ sqlite apacheHttpd jq headscale gnugrep coreutils gawk ];
        script = ''
          set -euo pipefail
          DB="${config.services.headscale.settings.database.sqlite.path or "/var/lib/headscale/db.sqlite"}"
          KEY="${headscale_authkey}"
          SYSTEMCTL="${config.systemd.package}/bin/systemctl"

          case "$KEY" in
            hskey-auth-*) ;;
            *) echo "HEADSCALE_PREAUTH_KEY must look like hskey-auth-<12chars>-<64chars>" >&2; exit 1 ;;
          esac
          RAW="''${KEY#hskey-auth-}"
          PREFIX="''${RAW:0:12}"
          SECRET="''${RAW:13}"
          if [ "''${#PREFIX}" -ne 12 ] || [ "''${#SECRET}" -ne 64 ]; then
            echo "malformed HEADSCALE_PREAUTH_KEY (need 12-char prefix + 64-char secret)" >&2; exit 1
          fi
          [ -f "$DB" ] || { echo "headscale db not found at $DB" >&2; exit 1; }

          if ! headscale users list 2>/dev/null | grep -qw mahmooz; then
            headscale users create mahmooz || true
          fi
          USER_ID=$(headscale users list -o json | jq -r '.[] | select(.name=="mahmooz") | .id // empty')
          [ -n "$USER_ID" ] || { echo "could not find headscale user mahmooz" >&2; exit 1; }

          if [ "$(sqlite3 "$DB" "SELECT COUNT(*) FROM pre_auth_keys WHERE prefix='$PREFIX';")" -ge 1 ]; then
            echo "pinned preauth key already present, nothing to do"
            exit 0
          fi

          # rotation needs a new full key (new prefix); same prefix is ignored.
          echo "inserting pinned preauth key"
          $SYSTEMCTL stop headscale.service
          trap '"$SYSTEMCTL" start headscale.service' EXIT
          HASH=$(htpasswd -bnBC 10 "" "$SECRET" | cut -d: -f2)
          sqlite3 "$DB" "INSERT INTO pre_auth_keys (created_at, expiration, user_id, reusable, ephemeral, used, tags, prefix, hash) VALUES ('1970-01-01 00:00:00.000000000+00:00', '2099-01-01 00:00:00.000000000+00:00', $USER_ID, 1, 0, 0, '[]', '$PREFIX', '$HASH');"
          trap - EXIT
          $SYSTEMCTL start headscale.service
        '';
        serviceConfig = {
          Type = "oneshot";
          Restart = "on-failure";
          RestartSec = 20;
        };
        unitConfig = {
          StartLimitIntervalSec = 600;
          StartLimitBurst = 30;
        };
      };
    }));
}
