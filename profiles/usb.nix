# portable mahmooz6 install on a usb stick, built by install-usb.sh.
# replaces hardware-configuration.nix, which pins x86_64 and the original disks.
{ config, pkgs, lib, system, modulesPath, ... }:

let
  constants = (import ../lib/constants.nix);
in
{
  config = {
    machine.name = "mahmooz6-usb";
    machine.is_desktop = false;
    machine.is_home_server = false;
    machine.can_compile = false;
    machine.low_resources = true;

    nixpkgs.hostPlatform = lib.mkForce system;

    fileSystems."/" = {
      device = "/dev/disk/by-partuuid/${constants.usb_root_partuuid}";
      fsType = "ext4";
      autoResize = true;
    };
    fileSystems."/boot" = {
      device = "/dev/disk/by-partuuid/${constants.usb_esp_partuuid}";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };
    swapDevices = [ ];
    boot.growPartition = true;

    # removable media must not depend on the host's efi nvram
    boot.loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
      devices = lib.mkForce [ "nodev" ];
      useOSProber = lib.mkForce false;
      copyKernels = true;
      configurationLimit = lib.mkForce 3;
    };
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    boot.initrd.availableKernelModules = [
      "usb_storage" "uas" "usbhid" "xhci_pci" "ehci_pci" "ohci_pci"
      "sd_mod" "sdhci_pci" "ahci" "nvme"
    ];

    # unknown target hardware: wifi/gpu firmware, and microcode for either x86 vendor
    hardware.enableRedistributableFirmware = true;
    hardware.cpu.intel.updateMicrocode = pkgs.stdenv.hostPlatform.isx86;
    hardware.cpu.amd.updateMicrocode = pkgs.stdenv.hostPlatform.isx86;

    networking.useDHCP = false;
    networking.networkmanager.enable = true;
    users.users.${config.machine.user}.extraGroups = [ "networkmanager" ];
    systemd.services.NetworkManager-wait-online.enable = false;

    # network.nix only enables the firewall on the exit node
    networking.firewall = {
      enable = lib.mkForce true;
      allowedTCPPorts = lib.mkForce [ 22 ];
      allowedUDPPorts = lib.mkForce [ ];
      trustedInterfaces = lib.mkForce [ ];
    };

    services.tailscale.enable = lib.mkForce false;

    system.build.usbImage = pkgs.callPackage "${modulesPath}/../lib/make-disk-image.nix" {
      inherit config;
      format = "raw";
      partitionTableType = "efi";
      diskSize = "auto";
      additionalSpace = "2G";
      bootSize = "512M";
      copyChannel = false;
      installBootLoader = true;
      rootGPUID = constants.usb_root_partuuid;
      rootFSUID = constants.usb_root_partuuid;
      label = "nixos-usb";
      name = "nixos-usb-mahmooz6-${pkgs.stdenv.hostPlatform.parsed.cpu.name}";
      baseName = "nixos-mahmooz6-usb";
    };
  };
}
