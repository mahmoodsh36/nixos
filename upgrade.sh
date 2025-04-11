#!/usr/bin/env sh
conf="$1"
[ -z "$conf" ] && conf="mahmooz1"
echo -e building for "\e[31m$conf\e[0m"
cd ~/work/nixos/
cp /etc/nixos/hardware-configuration.nix .
# sudo nixos-rebuild switch --upgrade --flake .#mahmooz --option eval-cache false --refresh --show-trace --impure "$@"
sudo nixos-rebuild switch --upgrade --flake .#"$conf" --show-trace --impure