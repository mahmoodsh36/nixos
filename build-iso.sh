#!/usr/bin/env bash

# Build NixOS ISO for specified architecture
# Usage: ./build-iso.sh [arch] [config]
# arch: x86_64 or aarch64 (default: x86_64)
# config: mahmooz1 or server (default: mahmooz1)

ARCH=${1:-x86_64}
CONFIG=${2:-mahmooz1}

if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    echo "Error: Unsupported architecture '$ARCH'. Use x86_64 or aarch64"
    exit 1
fi

if [[ "$CONFIG" != "mahmooz1" && "$CONFIG" != "server" ]]; then
    echo "Error: Unsupported config '$CONFIG'. Use mahmooz1 or server"
    exit 1
fi

echo "Building NixOS ISO for $ARCH-$CONFIG..."

CONFIG_NAME="${CONFIG}_iso-${ARCH}-linux"

echo "Building NixOS ISO: $CONFIG_NAME"

nix build ".#nixosConfigurations.${CONFIG_NAME}.config.system.build.isoImage" --show-trace --impure --option system ${ARCH}-linux