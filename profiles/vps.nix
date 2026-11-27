# generic kvm vps (hetzner, vultr), installed by install.sh via nixos-anywhere.
# the disk layout is in disko-vps.nix.
{ config, pkgs, lib, system, ... }:

let
  isx86 = pkgs.stdenv.hostPlatform.isx86;
in
{
  config = {
    nixpkgs.hostPlatform = system;

    machine.is_desktop = false;
    machine.is_home_server = false;
    machine.can_compile = false;
    machine.low_resources = true;

    # grub in both modes on x86, uefi only on arm. removable so no nvram writes are needed.
    boot.loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
      useOSProber = lib.mkForce false;
      devices = lib.mkForce (if isx86 then [ config.vps.disk ] else [ "nodev" ]);
    };
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    # hetzner uses virtio scsi, vultr virtio blk
    boot.initrd.availableKernelModules = [
      "virtio_pci" "virtio_scsi" "virtio_blk" "ahci" "xhci_pci" "sd_mod" "nvme"
    ];
    services.qemuGuest.enable = true;

    networking.useDHCP = lib.mkDefault true;
  };
}
