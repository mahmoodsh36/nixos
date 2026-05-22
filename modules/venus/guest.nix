{ config, lib, pkgs, modulesPath, ... }:

let
  inherit (lib) mkEnableOption mkOption mkIf mkForce mkDefault types;

  cfg = config.venus.guest;

  # Mesa with osy's 16-KiB blob-alignment patch (guest 4K vs host 16K
  # Apple-Silicon page size). Obsolete once F_BLOB_ALIGNMENT lands.
  mesa16kAlign = {
    url  = "https://gist.githubusercontent.com/osy/a8f705050eed1c8421ad1a0855a8faa9/raw/1080c476b50ac1ec379def46ba9d78561e582635/0001-DO-NOT-MERGE-venus-hack-to-align-mappings-to-16KiB.patch";
    hash = "sha256-DbitYq+/wl5SSHk+jeIcTvReZZ3Vojx5alicYShC/qU=";
  };

  guestOverlay = final: prev: {
    mesa = prev.mesa.overrideAttrs (old: {
      patches = (old.patches or []) ++ [
        (final.fetchurl {
          name = "mesa-venus-16k-blob-align.patch";
          url  = mesa16kAlign.url;
          hash = mesa16kAlign.hash;
        })
      ];
    });

    # Pure-compute Vulkan benchmark; confirms Venus dispatches run on
    # the GPU (llvmpipe: MFLOPS, real HW: TFLOPS).
    vkpeak = prev.stdenv.mkDerivation {
      pname = "vkpeak";
      version = "20260112";
      src = final.fetchFromGitHub {
        owner = "nihui";
        repo  = "vkpeak";
        rev   = "1c5c383c79cb0ff2485ac453f3ddd25535f41ca5";
        hash  = "sha256-PoZ6p0XGt5NZ5sH/171IKK5n8lYHSqYfox36QPWLIvw=";
        fetchSubmodules = true;
      };
      nativeBuildInputs = [ final.cmake ];
      buildInputs       = [ final.vulkan-loader final.vulkan-headers ];
      installPhase = ''
        runHook preInstall
        install -Dm755 vkpeak "$out/bin/vkpeak"
        runHook postInstall
      '';
    };
  };
in {
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/profiles/minimal.nix"
  ];

  options.venus.guest = {
    enable = mkEnableOption "Venus (virtio-gpu) GPU-passthrough guest profile";

    rootInitialPassword = mkOption {
      type        = types.str;
      default     = "venus";
      description = "Initial root password for the Venus guest (change after first boot).";
    };

    hostName = mkOption {
      type        = types.str;
      default     = "venus-guest";
      description = "Guest hostname.";
    };

    stateVersion = mkOption {
      type        = types.str;
      default     = "25.05";
      description = "system.stateVersion for the Venus guest.";
    };
  };

  config = mkIf cfg.enable {
    nixpkgs.overlays = [ guestOverlay ];

    # Legacy (non-systemd) initrd: systemd-in-initrd + make-disk-image
    # emits a duplicate sysroot.mount and drops to emergency mode.
    boot.loader.grub.enable         = mkForce false;
    boot.loader.systemd-boot.enable = mkForce false;
    boot.initrd.systemd.enable      = false;
    boot.initrd.availableKernelModules = [
      "virtio_pci" "virtio_blk" "virtio_net" "virtio_gpu"
      "drm" "drm_kms_helper"
      # 9p for the /nix/store mount below. Builtins in the aarch64
      # kernel; don't add fscache/netfs (not packaged, breaks modprobe -S).
      "9p" "9pnet" "9pnet_virtio"
    ];
    boot.kernelModules = [ "virtio_gpu" ];
    # qemu-guest.nix sets ttyS0 (x86); aarch64 virt uses ttyAMA0.
    boot.kernelParams = mkForce [
      "console=ttyAMA0,115200"
      "console=tty0"
    ];

    # mkForce to override any fileSystems."/" from the parent config's
    # hardware-configuration.nix. Empty disk provisioned by the launcher.
    fileSystems."/" = mkForce {
      device     = "/dev/disk/by-label/nixos";
      fsType     = "ext4";
      autoResize = true;
    };

    # Host /nix/store over 9p instead of baking the ~63 GB closure into
    # the disk. neededForBoot so stage-1 mounts it before switching root
    # (the init= cmdline path lives under /nix/store).
    fileSystems."/nix/store" = mkForce {
      device       = "nix-store";
      fsType       = "9p";
      options      = [ "trans=virtio" "version=9p2000.L" "msize=1048576" "ro" "cache=loose" ];
      neededForBoot = true;
    };

    services.openssh.enable = true;
    services.openssh.settings.PermitRootLogin = "yes";
    users.users.root.initialPassword = cfg.rootInitialPassword;

    hardware.graphics.enable = true;

    # Pin the venus ICD so the loader doesn't try (and noisily fail) the
    # other Mesa drivers first.
    environment.sessionVariables.VK_DRIVER_FILES =
      "/run/opengl-driver/share/vulkan/icd.d/virtio_icd.aarch64.json";
    environment.sessionVariables.VK_ICD_FILENAMES =
      "/run/opengl-driver/share/vulkan/icd.d/virtio_icd.aarch64.json";

    environment.systemPackages = with pkgs; [
      vulkan-tools
      vulkan-loader
      vulkan-validation-layers
      mesa-demos
      glmark2
      vkmark
      vkpeak                # pure-compute GPU verification
      kmscube
      weston
    ];

    # mkDefault so a parent config (mahmooz1 etc.) we layer onto wins.
    networking.hostName        = mkDefault cfg.hostName;
    networking.firewall.enable = mkDefault false;

    system.stateVersion = mkDefault cfg.stateVersion;
  };
}