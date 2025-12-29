{ config, lib, system, hostPkgs, hostVoldir, ... }:

{
  services.qemuGuest.enable = true;

  virtualisation = {
    memorySize = 16000;
    cores = 8;
    diskSize = 80 * 1024;
    fileSystems."/".autoResize = true;
    graphics = config.machine.is_desktop;
    diskImage = "\${NIX_DISK_IMAGE:-${hostVoldir}/vm/mahmooz1${if config.machine.is_desktop then "" else "-headless"}.qcow2}";
    resolution = { x = 1280; y = 720; };

    host.pkgs = hostPkgs;

    qemu = {
      # use mkForce to override the default virtio networking from qemu-vm.nix module
      # which causes TX timeout issues on macOS hosts
      networkingOptions = lib.mkForce [
      ];
    };
  };

  nixpkgs.hostPlatform = lib.mkForce system;
  hardware.cpu.intel.updateMicrocode = lib.mkForce false;
  networking.usePredictableInterfaceNames = lib.mkForce false;
}