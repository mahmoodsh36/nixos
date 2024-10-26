{ pkgs, modulesPath, lib, ... }: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    # provide an initial copy of the NixOS channel so that the user
    # doesn't need to run "nix-channel --update" first.
    # <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
    "/etc/nixos/configuration.nix"
  ];
  # recommended by the wiki for speeding up build time
  # suboptimal for production tho :p
  isoImage.squashfsCompression = "gzip -Xcompression-level 1";
  networking.wireless.enable = false; # installation-cd-minimal.nix sets that to true

  # needed for https://github.com/nixos/nixpkgs/issues/58959
  boot.supportedFilesystems = lib.mkForce [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" ];
}