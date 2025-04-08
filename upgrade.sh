#!/usr/bin/env sh
cd ~/work/nixos/
cp /etc/nixos/hardware-configuration.nix .
# sudo nixos-rebuild switch --upgrade --flake .#mahmooz --option eval-cache false --refresh --show-trace --impure "$@"
sudo nixos-rebuild switch --upgrade --flake .#mahmooz --show-trace --impure "$@"