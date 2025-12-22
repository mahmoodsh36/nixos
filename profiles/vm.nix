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
      networkingOptions = [
        # port 2222 to port 22
        "-nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22"
        "-nic user,model=virtio-net-pci,hostfwd=tcp::8088-:8088"
      ];
      options = [
        "-device qemu-xhci"
        "-device virtio-serial-pci"
      ] ++ lib.optionals config.machine.is_desktop [
        "-device virtio-gpu-pci" # virtio-gpu-gl requires OpenGL support (disabled on macOS)
        "-display cocoa,gl=off" # gl=es requires OpenGL which needs EGL (Linux-only)
      ];
    };
  };

  nixpkgs.hostPlatform = lib.mkForce system;
  hardware.cpu.intel.updateMicrocode = lib.mkForce false;
  networking.usePredictableInterfaceNames = lib.mkForce false;
}