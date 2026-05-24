# Guest-side NixOS profile for the Venus VM.
#
# We can't import qemu-vm.nix (it's Linux-host-only and tightly coupled
# to vmVariant's runner), so we lift only the patterns we need:
# overlayfs /nix/store on a 9p RO lower + tmpfs upper, ext4 scratch /
# with autoResize, /tmp tmpfs, legacy initrd, aarch64 ttyAMA0 console,
# regInfo-driven nix db registration. See ./default.nix for the launcher.

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

    # Legacy initrd; systemd-in-initrd + make-disk-image emit a
    # duplicate sysroot.mount and drop to emergency mode. Bootloaders
    # off — the launcher boots via qemu -kernel/-initrd directly.
    boot.loader.grub.enable         = mkForce false;
    boot.loader.systemd-boot.enable = mkForce false;
    boot.initrd.systemd.enable      = false;
    boot.initrd.availableKernelModules = [
      "virtio_pci" "virtio_blk" "virtio_net" "virtio_gpu"
      "drm" "drm_kms_helper"
      # 9p modules are built into the aarch64 kernel; don't add
      # fscache/netfs (unpackaged, breaks modprobe -S).
      "9p" "9pnet" "9pnet_virtio"
      "overlay"
    ];
    boot.kernelModules = [ "virtio_gpu" ];
    # aarch64 virt = ttyAMA0 (qemu-guest.nix's ttyS0 default is x86).
    boot.kernelParams = mkForce [ "console=ttyAMA0,115200" "console=tty0" ];

    # Root: 1 GiB ext4 scratch, grown to 32 GiB on first boot via
    # autoResize after the launcher's qemu-img resize. mkForce
    # overrides the parent's hardware-configuration.nix.
    fileSystems."/" = mkForce {
      device     = "/dev/disk/by-label/nixos";
      fsType     = "ext4";
      autoResize = true;
    };

    fileSystems."/tmp" = {
      device  = "tmpfs";
      fsType  = "tmpfs";
      options = [ "mode=1777" ];
    };

    # Host machine.voldir (e.g. /Volumes/main on mahmooz0) shared as 9p.
    # mkForce because mahmooz1's disko-raid1.nix declares /data as btrfs.
    # security_model=none passes through host UIDs — guest sees files
    # owned by host's uid (501 on macOS), which mismatches guest
    # mahmooz=1000; access as root or fix perms if you need to write
    # as user. `nofail` so the VM boots even when launched without
    # the corresponding -virtfs (linux host build path).
    fileSystems."/data" = mkForce {
      device  = "host-data";
      fsType  = "9p";
      options = [ "trans=virtio" "version=9p2000.L" "msize=1048576" "rw" "nofail" ];
    };

    # /nix/store: 9p RO lower + tmpfs upper overlayfs. nix-daemon dies
    # on a RO store, which breaks HM activation. tmpfs writes are lost
    # on reboot — fine, the VM shouldn't persist new store paths.
    # neededForBoot because init=${toplevel}/init lives under /nix/store.
    fileSystems."/nix/.ro-store" = mkForce {
      device        = "nix-store";
      fsType        = "9p";
      options       = [ "trans=virtio" "version=9p2000.L" "msize=1048576" "ro" "cache=loose" ];
      neededForBoot = true;
    };
    fileSystems."/nix/.rw-store" = {
      fsType        = "tmpfs";
      options       = [ "mode=0755" ];
      neededForBoot = true;
    };
    fileSystems."/nix/store" = mkForce {
      overlay = {
        lowerdir = [ "/nix/.ro-store" ];
        upperdir = "/nix/.rw-store/upper";
        workdir  = "/nix/.rw-store/work";
      };
      neededForBoot = true;
    };

    # Lifted from qemu-vm.nix. Loads the regInfo file (passed via
    # kernel cmdline by the launcher) into the local nix db before
    # nix-daemon starts, so realise resolves closure paths locally
    # instead of falling back to substituters.
    systemd.services.register-nix-paths = {
      description = "Load regInfo into nix store db";
      unitConfig.DefaultDependencies = false;
      wantedBy   = [ "sysinit.target" ];
      before     = [ "sysinit.target" "shutdown.target"
                     "nix-daemon.socket" "nix-daemon.service" ];
      after      = [ "local-fs.target" ];
      conflicts  = [ "shutdown.target" ];
      restartIfChanged = false;
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        if [[ "$(cat /proc/cmdline)" =~ regInfo=([^ ]*) ]]; then
          ${lib.getExe' config.nix.package.out "nix-store"} --load-db < "''${BASH_REMATCH[1]}"
        fi
      '';
    };

    # Offline nix: regInfo covers the happy path, empty substituters
    # as defense-in-depth, tight connect-timeout fails fast on any
    # stray network-bound op instead of stalling boot.
    nix.settings.substituters         = lib.mkForce [ ];
    nix.settings.trusted-substituters = lib.mkForce [ ];
    nix.settings.connect-timeout      = 1;

    services.openssh.enable = true;
    services.openssh.settings.PermitRootLogin = "yes";
    users.users.root.initialPassword = cfg.rootInitialPassword;

    hardware.graphics.enable = true;

    # Pin the venus ICD so the loader doesn't noisily try other drivers.
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