#!/usr/bin/env sh
cd ~/work/nixos/
cp /etc/nixos/hardware-configuration.nix .
sudo nixos-rebuild switch --upgrade --flake .#mahmooz --option eval-cache false --show-trace
