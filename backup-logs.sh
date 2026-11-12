#!/usr/bin/env bash
# copy a server's caddy logs to $DATA_DIR/backup/backup<n>, n being the next free number.
set -euo pipefail

HOST=${1:-mahmooz3}
[ -n "${DATA_DIR:-}" ] || { echo "error: DATA_DIR is not set" >&2; exit 1; }

n=1
for d in "$DATA_DIR"/backup/backup*; do
  [ -d "$d" ] || continue
  i=${d##*/backup}
  [[ $i =~ ^[0-9]+$ ]] || continue
  i=$((10#$i))
  [ "$i" -lt "$n" ] || n=$((i + 1))
done

dest="$DATA_DIR/backup/backup$n"
mkdir -p "$dest"
echo "copying $HOST:/var/log/caddy to $dest"
# the logs are owned by caddy with mode 0600, so the remote rsync needs sudo
rsync -az --progress --rsync-path='sudo rsync' "$HOST:/var/log/caddy/" "$dest/" \
  || { rmdir "$dest" 2>/dev/null || true; exit 1; }
