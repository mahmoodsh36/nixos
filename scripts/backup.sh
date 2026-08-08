# pull a full snapshot (ghost db + uploads + caddy logs) from a host into
# $vol/data/backups/<host>/<timestamp>
set -euo pipefail

host="${1:-mahmooz3}"
root="${DATA_DIR:-${vol:-/Volumes/main}/data}/backups/$host"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
dest="$root/$ts"
latest="$root/latest"

echo "==> $host -> $dest"

if ! ssh -o ConnectTimeout=10 "$host" 'sudo podman container exists ghost-db'; then
  echo "ghost-db is not running on $host" >&2
  exit 1
fi

mkdir -p "$dest"

# dump over the wire so no copy is left behind on the server
echo "--> database"
ssh "$host" '
  set -a; . ~/work/nixos/env.sh; set +a
  sudo podman exec -e MYSQL_PWD="$GHOST_DB_PASSWORD" ghost-db \
    mysqldump --user=ghost --single-transaction --routines --no-tablespaces ghost
' | gzip > "$dest/db.sql.gz"

# hardlink unchanged files against the previous snapshot, uploads and rotated
# logs never change once written, so repeat snapshots cost almost nothing
link_content=()
link_caddy=()
if [ -d "$latest" ]; then
  [ -d "$latest/content" ] && link_content=(--link-dest="$(cd "$latest/content" && pwd -P)")
  [ -d "$latest/caddy" ] && link_caddy=(--link-dest="$(cd "$latest/caddy" && pwd -P)")
fi

echo "--> content"
rsync -a --rsync-path="sudo rsync" "${link_content[@]}" \
  "$host:/var/lib/ghost/content/" "$dest/content/"

echo "--> caddy logs"
rsync -a --rsync-path="sudo rsync" "${link_caddy[@]}" \
  "$host:/var/log/caddy/" "$dest/caddy/"

ssh "$host" 'sudo podman inspect --format "{{.ImageName}}" ghost ghost-db' \
  > "$dest/images.txt" 2>/dev/null || true

ln -sfn "$dest" "$latest"

echo "==> done: $(du -sh "$dest" | cut -f1) at $dest"
