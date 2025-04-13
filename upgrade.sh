#!/usr/bin/env sh
conf="$1"
# [ -z "$conf" ] && conf="mahmooz1"
if [ -z "$conf" ]; then
    echo please enter host to build for
    exit
fi
echo -e building for "\e[31m$conf\e[0m"
cd ~/work/nixos/
# cp /etc/nixos/hardware-configuration.nix .
# sudo nixos-rebuild switch --upgrade --flake .#mahmooz --option eval-cache false --refresh --show-trace --impure "$@"
# sudo nixos-rebuild switch --upgrade --flake .#mahmooz --show-trace --impure --option eval-cache false --refresh
sudo nixos-rebuild switch --upgrade --flake .#"$conf" --show-trace --impure