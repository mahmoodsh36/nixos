#!/usr/bin/env sh
conf="$1"
# [ -z "$conf" ] && conf="mahmooz1"
if [ -z "$conf" ]; then
    echo please enter host to build for
    exit
fi
echo -e building for "\e[31m$conf\e[0m"
[ -f ~/brain/moredots/env.sh ] && source ~/brain/moredots/env.sh
[ -f ./env.sh ] && source ./env.sh
cd ~/work/nixos/
# cp /etc/nixos/hardware-configuration.nix .
# sudo nixos-rebuild switch --upgrade --flake .#mahmooz --option eval-cache false --refresh --show-trace --impure "$@"
# sudo nixos-rebuild switch --upgrade --flake .#mahmooz --show-trace --impure --option eval-cache false --refresh
# EXPORT MAX_JOBS=6; sudo -E nixos-rebuild switch --upgrade --flake .#mahmooz2 --option cores 6 --option max-jobs 6 --impure
if [ "$conf" == "droid" ]; then
    nix-on-droid switch --flake .#"$conf" --show-trace
elif [ "$conf" == "mahmooz0" ]; then
  sudo darwin-rebuild switch --flake .#mahmooz0 --show-trace --impure
else
    # sudo -E nixos-rebuild switch --upgrade --flake .#"$conf" --show-trace --impure --install-bootloader
    # the -E option is sometimes problematic, but nixos-rebuild has to be run as root
    sudo -E nixos-rebuild switch --flake .#"$conf" --show-trace --impure --install-bootloader
fi
