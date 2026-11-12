#!/usr/bin/env bash
# convert a running non-nixos linux vps to nixos over ssh (nixos-anywhere). wipes the target disk.
set -euo pipefail

usage() {
  cat <<'EOF'
usage: ./install.sh [-i KEY] [-k] [-l] [-n] HOST root@IP

  HOST  flake host to install (e.g. mahmooz3)
  -i    ssh private key to log in with
  -k    keep the target's ssh host keys
  -l    build here and upload instead of building on the target
  -n    check everything and print the command, install nothing

by default the system is built on the target, which needs about 2 GB of ram.
secrets are read from env.sh like upgrade.sh does.
EOF
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
KEEPKEYS=0 LOCAL=0 DRY=0 KEY=""
while getopts i:klnh opt; do
  case $opt in
    i) KEY=$OPTARG ;;
    k) KEEPKEYS=1 ;;
    l) LOCAL=1 ;;
    n) DRY=1 ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
[ $# -eq 2 ] || { usage >&2; exit 1; }
NAME=$1 HOST=$2
[[ $HOST == *@* ]] || die "give the target as root@host"
SSHOPTS=(-o ConnectTimeout=10)
[ -z "$KEY" ] || SSHOPTS+=(-i "$KEY" -o IdentitiesOnly=yes)

# shellcheck source=/dev/null
[ ! -f ~/brain/moredots/env.sh ] || source ~/brain/moredots/env.sh
# shellcheck source=/dev/null
[ ! -f "$REPO/env.sh" ] || source "$REPO/env.sh"

probe=$(ssh "${SSHOPTS[@]}" -o BatchMode=yes "$HOST" sh -s <<'EOF'
echo "arch=$(uname -m)"
echo "ram=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
echo "disk=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null | head -n 1)"
EOF
) || die "cannot ssh to $HOST"
get() { sed -n "s/^$1=//p" <<<"$probe"; }

ATTR="$NAME-$(get arch)-linux"
NIXOPTS=(--option pure-eval false)
DISK=$(nix eval --raw "${NIXOPTS[@]}" "$REPO#nixosConfigurations.$ATTR.config.vps.disk" 2>/dev/null) \
  || die "cannot evaluate $ATTR (is it a vps host?)"
nix eval --raw "${NIXOPTS[@]}" "$REPO#nixosConfigurations.$ATTR.config.system.build.toplevel.drvPath" >/dev/null \
  || die "the config for $ATTR does not evaluate"
[ -z "$(get disk)" ] || [ "$DISK" = "/dev/$(get disk)" ] \
  || die "$NAME installs to $DISK but the target's root disk is /dev/$(get disk)"
[ "$(get ram)" -ge 1900 ] || printf 'warning: only %s MB of ram, building on the target may run out of memory\n' "$(get ram)" >&2

EXIT=$(nix eval --json "${NIXOPTS[@]}" "$REPO#nixosConfigurations.$ATTR.config.machine.is_exit_node")
if [ "$EXIT" = true ]; then
  for v in HEADSCALE_PREAUTH_KEY GRAFANA_PASSWORD; do
    [ -n "${!v:-}" ] || printf 'warning: %s is not set, so that service will be left out\n' "$v" >&2
  done
fi

CMD=(nixos-anywhere --flake "$REPO#$ATTR" "${NIXOPTS[@]}" -L)
[ "$LOCAL" -eq 1 ] || CMD+=(--build-on-remote)
[ "$KEEPKEYS" -eq 0 ] || CMD+=(--copy-host-keys)
[ -z "$KEY" ] || CMD+=(-i "$KEY")

printf '\n  host:   %s\n  target: %s (%s MB ram)\n  disk:   %s\n' "$ATTR" "$HOST" "$(get ram)" "$DISK"
if [ "$DRY" -eq 1 ]; then
  printf '\nwould run:\n  %s\n  %s\n' "${CMD[*]} --phases kexec $HOST" "${CMD[*]} --phases disko,install,reboot $HOST"
  exit 0
fi

printf '\nthis ERASES ALL DATA on %s:%s.\n' "$HOST" "$DISK"
read -rp "type '${HOST#*@}' to continue: " answer
[ "$answer" = "${HOST#*@}" ] || die aborted

"${CMD[@]}" --phases kexec "$HOST"
# the installer's nix store is a small tmpfs, and its auto gc deletes .drv files mid build
ssh "${SSHOPTS[@]}" "$HOST" 'c=$(cat /etc/nix/nix.conf) && rm /etc/nix/nix.conf && printf "%s\nmin-free = 0\n" "$c" > /etc/nix/nix.conf && systemctl restart nix-daemon'
"${CMD[@]}" --phases disko,install,reboot "$HOST"
