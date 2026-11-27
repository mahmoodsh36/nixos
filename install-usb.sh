#!/usr/bin/env bash
# write the mahmooz6-usb image (profiles/usb.nix) to a usb drive, erasing it.
set -euo pipefail

usage() {
  cat <<'EOF'
usage: ./install-usb.sh [-a x86_64|aarch64] [-y] [-f] DEVICE

  DEVICE     whole disk to erase (macos: /dev/diskN, linux: /dev/sdX)
  -a ARCH    target architecture (default: x86_64)
  -y         do not ask for confirmation
  -f         allow devices that do not report as usb (never internal ones)

the result boots on uefi machines, not on apple silicon macs.
EOF
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
msg() { printf '==> %s\n' "$*"; }

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ARCH=x86_64 YES=0 FORCE=0
while getopts a:yfh opt; do
  case $opt in
    a) ARCH=$OPTARG ;;
    y) YES=1 ;;
    f) FORCE=1 ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || { usage >&2; exit 1; }
DEVICE=$1
OS=$(uname -s)
SUDO=(); [ "$(id -u)" -eq 0 ] || SUDO=(sudo)

if [ "$OS" = Darwin ]; then
  DEVICE=/dev/${DEVICE#/dev/}; DEVICE=${DEVICE/#\/dev\/rdisk//dev/disk}
  [[ $DEVICE =~ ^/dev/disk[0-9]+$ ]] || die "expected a whole disk such as /dev/disk4, got '$DEVICE'"
  info=$(diskutil info -plist "$DEVICE") || die "cannot read $DEVICE"
  get() { plutil -extract "$1" raw -o - - <<<"$info" 2>/dev/null || echo unknown; }
  [ "$(get WholeDisk)" = true ] || die "$DEVICE is not a whole disk"
  [ "$(get Internal)" = false ] || die "refusing: $DEVICE is internal"
  bus=$(get BusProtocol)
  SIZE=$(get TotalSize) MODEL=$(get MediaName)
else
  DEVICE=$(readlink -f -- "$DEVICE")
  [ -b "$DEVICE" ] || die "'$DEVICE' is not a block device"
  [ "$(lsblk -dno TYPE "$DEVICE")" = disk ] || die "$DEVICE is not a whole disk"
  bus=$(lsblk -dno TRAN "$DEVICE" | tr -d ' ')
  [ "$(lsblk -dno RM "$DEVICE" | tr -d ' ')" = 1 ] && bus=usb
  # an external ssd could still be the running system
  if lsblk -lno MOUNTPOINT "$DEVICE" | grep -Eqx '/|/boot.*|/nix.*|/home.*|\[SWAP\]'; then
    die "refusing: $DEVICE is in use by the running system"
  fi
  SIZE=$(lsblk -bdno SIZE "$DEVICE" | tr -d ' ') MODEL=$(lsblk -dno MODEL "$DEVICE")
fi
case $bus in
  USB|usb|"Secure Digital") ;;
  *) [ "$FORCE" -eq 1 ] || die "refusing: $DEVICE bus is '$bus', not usb (-f to override)" ;;
esac


ATTR="$REPO#nixosConfigurations.mahmooz6-usb-$ARCH-linux.config.system.build.usbImage"
msg "building the $ARCH-linux image"
out=$(nix build --no-link --print-out-paths -L "$ATTR")
IMAGE=$out/nixos-mahmooz6-usb.img
[ -f "$IMAGE" ] || die "no image at $IMAGE"

if [ "$OS" = Darwin ]; then img_size=$(stat -f %z "$IMAGE"); else img_size=$(stat -c %s "$IMAGE"); fi
[ "$img_size" -le "$SIZE" ] || die "image ($img_size bytes) is larger than $DEVICE ($SIZE bytes)"

printf '\n  device: %s (%s, %s bytes)\n  image:  %s\n\nthis ERASES ALL DATA on %s.\n' \
  "$DEVICE" "$MODEL" "$SIZE" "$IMAGE" "$DEVICE"
if [ "$YES" -ne 1 ]; then
  read -rp "type '${DEVICE##*/}' to continue: " answer
  [ "$answer" = "${DEVICE##*/}" ] || die aborted
fi

if [ "$OS" = Darwin ]; then
  diskutil unmountDisk "$DEVICE" >/dev/null
  sudo dd if="$IMAGE" of="/dev/r${DEVICE#/dev/}" bs=4m
  diskutil eject "$DEVICE" >/dev/null || true
else
  lsblk -lnpo NAME,MOUNTPOINT "$DEVICE" | while read -r part mnt; do
    [ -z "$mnt" ] || "${SUDO[@]}" umount "$part"
  done
  "${SUDO[@]}" dd if="$IMAGE" of="$DEVICE" bs=4M oflag=direct status=progress conv=fsync
fi
msg "done; the root partition grows to fill the drive on first boot"
