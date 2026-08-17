# Venus GPU passthrough: aarch64-linux NixOS guest with Venus->Metal
# on aarch64-darwin, built from UTM's macOS-Venus tree.
#
# Replaces qemu-vm.nix/vmVariant (which is Linux-host-only): the
# launcher is a darwin writeShellApplication wrapping the UTM-fork
# qemu; the guest's filesystem/init bits live in ./guest.nix.
# Guest derivations (kernel/initrd) need a linux builder.

{ nixpkgs
, hostSystem ? "aarch64-darwin"
, guestSystem ? "aarch64-linux"
, lib ? nixpkgs.lib
# An externally-built nixosSystem to boot as the guest (e.g. mahmooz1
# extended with the venus-guest module). When null, builds the stub
# guest in ./guest.nix.
, customGuest ? null
# Absolute path on the host to share into the guest at /data via 9p.
# When null, /data is left unmounted.
, hostVoldir ? null
# Default network backend: "user" (slirp NAT, unprivileged), "vmnet"
# (Apple vmnet shared NAT, needs root) or "none". Overridable per-run
# with VENUS_NET=... without rebuilding the launcher.
, defaultNetwork ? "user"
# Host-side port forwarded to the guest's sshd under the "user" backend.
, sshHostPort ? 2222
# null packs the store image uncompressed (~2.5x the size, no per-read
# decompression); a string goes to sqfstar -comp, e.g. "zstd -Xcompression-level 3".
, storeImageCompression ? null
}:

let
  sources = {
    # utmapp/virglrenderer @ branch macos (osy's open virgl MRs).
    virglrenderer = {
      rev  = "71a67414013f120c158729da7f56f29b55bf4f6c";
      hash = "sha256-k/yk3RGam6Xj7ZmY37jEJgXaA3+qrilyFDUJtX2ebJM=";
    };

    # utmapp/libepoxy @ branch macos-venus. Stock nixpkgs libepoxy
    # disables EGL on darwin; this branch wires up ANGLE.
    libepoxy = {
      rev  = "15d904dcb1d5a8d626ffe11e8f3339499d6f7b09";
      hash = "sha256-NTjklUW3Tpb7IwuXxtU1ANoK1f6iGt+54p4A+CGBmio=";
    };

    # utmapp/MoltenVK @ branch macos, 3 fixes ahead of Khronos needed
    # for stable Venus-on-Metal interop.
    moltenvk = {
      rev  = "6f2002d1a583c3347827cbce1c1b8a33aeec2077";
      hash = "sha256-wYBRMscfiyrKpqjoyGTJ6ukhTLTNlkSvJ/h1kfTxl3Q=";
    };
  };

  hostOverlay = final: prev: let
    # UTM's release tarball, with all meson subprojects vendored. We
    # borrow subprojects/ from it to avoid wrap-git fetches in the
    # sandbox; both qemu branches consume the same wrap files.
    qemuSubprojectsBlob = final.fetchurl {
      name = "qemu-10.0.2-utm.tar.xz";
      url  = "https://github.com/utmapp/qemu/releases/download/v10.0.2-utm/qemu-10.0.2-utm.tar.xz";
      hash = "sha256-8dc1dUenGuMzmhFdXI8rcuOwCJUx1nwqykMybTIKxso=";
    };

    mkQemuVenus = {
      pname,
      rev,
      srcHash,
      versionSuffix,
      extraPatches ? [],
    }: (prev.qemu.override {
      # openGLSupport=false avoids libgbm/libdrm (broken on darwin); we
      # re-add libepoxy via overlay and --enable-opengl below.
      hostCpuTargets = [ "aarch64-softmmu" ];
      virglSupport   = true;
      openGLSupport  = false;
    }).overrideAttrs (old: {
      inherit pname;
      version = "${versionSuffix}-${builtins.substring 0 7 rev}";

      src = final.fetchFromGitHub {
        owner           = "utmapp";
        repo            = "qemu";
        inherit rev;
        hash            = srcHash;
        fetchSubmodules = true;
      };

      postPatch = ''
        ${old.postPatch or ""}
        # Git source has empty meson-subproject dirs; overlay the
        # populated ones from UTM's release tarball before meson runs.
        tmpdir=$(mktemp -d)
        ${final.gnutar}/bin/tar -xJf ${qemuSubprojectsBlob} -C "$tmpdir"
        for d in "$tmpdir"/qemu-10.0.2-utm/subprojects/*/; do
          name=$(basename "$d")
          rm -rf "subprojects/$name"
          cp -R "$d" "subprojects/$name"
        done
        rm -rf "$tmpdir"

        # nixpkgs apple-sdk_26 ships older headers without
        # HV_SYS_REG_ACTLR_EL1; substitute the literal MRS encoding.
        substituteInPlace target/arm/hvf/hvf.c \
          --replace-quiet HV_SYS_REG_ACTLR_EL1 '((hv_sys_reg_t)0xc081)'

        # Rez/SetFile (Finder icon) were removed from Xcode 14+; only
        # the codesign below them matters for HVF. Neutralise them.
        substituteInPlace scripts/entitlement.sh \
          --replace-quiet 'Rez -append' ': skip-Rez' \
          --replace-quiet 'SetFile -a C' ': skip-SetFile'
      '';

      # UTM's tree already carries the nixpkgs vendored patches' intent;
      # drop them. extraPatches carries the spice EGL-thread fix.
      patches = extraPatches;

      buildInputs = (old.buildInputs or []) ++ [
        final.virglrenderer
        final.libepoxy
        final.angle
        final.moltenvk
      ];

      configureFlags = (old.configureFlags or []) ++ [
        "--enable-opengl"
      ];
    });
  in {
    libepoxy = prev.libepoxy.overrideAttrs (old: {
      pname   = "libepoxy-utm";
      version = "macos-venus-${builtins.substring 0 7 sources.libepoxy.rev}";
      src = final.fetchFromGitHub {
        owner = "utmapp";
        repo  = "libepoxy";
        rev   = sources.libepoxy.rev;
        hash  = sources.libepoxy.hash;
      };
      # No system EGL on darwin; ANGLE supplies EGL/eglplatform.h + libEGL.
      buildInputs = (old.buildInputs or []) ++ [ final.angle ];
      mesonFlags = (lib.filter
        (f: !(lib.hasPrefix "-Dglx=" f || lib.hasPrefix "-Degl=" f
            || lib.hasPrefix "-Dtests=" f))
        (old.mesonFlags or [])) ++ [
        "-Dtests=false"
        "-Dglx=no"
        "-Degl=yes"
      ];
      # Resolve EGL/GLES to ANGLE's dylibs by absolute store path
      # instead of the Apple frameworks that only exist in a .app bundle.
      postPatch = ''
        ${old.postPatch or ""}
        substituteInPlace src/dispatch_common.c \
          --replace-quiet 'EGL.framework/Versions/Current/EGL' \
                          '${final.angle}/lib/libEGL.dylib' \
          --replace-quiet 'GLESv1_CM.framework/Versions/Current/GLESv1_CM' \
                          '${final.angle}/lib/libGLESv1_CM.dylib' \
          --replace-quiet 'GLESv2.framework/Versions/Current/GLESv2' \
                          '${final.angle}/lib/libGLESv2.dylib'
      '';
    });

    moltenvk = prev.moltenvk.overrideAttrs (old: {
      pname   = "moltenvk-utm";
      version = "macos-${builtins.substring 0 7 sources.moltenvk.rev}";
      src = final.fetchFromGitHub {
        owner = "utmapp";
        repo  = "MoltenVK";
        rev   = sources.moltenvk.rev;
        hash  = sources.moltenvk.hash;
      };
    });

    virglrenderer = prev.virglrenderer.overrideAttrs (old: {
      pname   = "virglrenderer-utm";
      version = "macos-${builtins.substring 0 7 sources.virglrenderer.rev}";
      src = final.fetchFromGitHub {
        owner = "utmapp";
        repo  = "virglrenderer";
        rev   = sources.virglrenderer.rev;
        hash  = sources.virglrenderer.hash;
      };
      buildInputs = (old.buildInputs or []) ++ [
        final.libepoxy
        final.angle
        final.moltenvk
        final.vulkan-headers
        final.vulkan-loader
      ];
      mesonFlags = (old.mesonFlags or []) ++ [
        "-Dtests=false"
        "-Dcheck-gl-errors=false"
        "-Dvenus=true"
        "-Dvulkan-dload=false"
        "-Drender-server-worker=thread"
        "-Dplatforms=egl"
      ];
    });

    # Windowed launcher (cocoa-GL). utmapp/qemu submit/macos-venus.
    qemu-venus = mkQemuVenus {
      pname         = "qemu-utm-venus";
      rev           = "f714f0e3370e8b4858a249ebaf6522f19b2fd97f";
      srcHash       = "sha256-6SYMl/5K4WweAAkIvoUB+DVdFpq7r+2CR1LzbDXLMDo=";
      versionSuffix = "10.0.2-utm";
    };

    # Console launcher (spice-IOSurface, no NSWindow). utmapp/qemu
    # utm-edition-venus.
    #
    # extraPatches: the spice EGL context is created+bound on the main
    # thread during init, but spice_gl_refresh runs on a separate
    # pthread, where ANGLE/Metal returns EGL_BAD_ACCESS for an
    # eglMakeCurrent on a context still current elsewhere. The patch
    # releases the context on the main thread so the worker can claim it.
    qemu-venus-spice = mkQemuVenus {
      pname         = "qemu-utm-venus-spice";
      rev           = "9f81c6232fbb3ea1d9e43cb67fe5e029723d2ed5";
      srcHash       = "sha256-pRyx6v1Ult0XptyLXh4sgCGnC5EM3HGhotsyI9W0bMo=";
      versionSuffix = "10.0.2-utm-edition";
      extraPatches  = [ ./spice-thread-fix.patch ];
    };
  };

  hostPkgs = import nixpkgs {
    system   = hostSystem;
    overlays = [ hostOverlay ];
    config.allowUnfree = true;
  };

  nixosGuest =
    if customGuest != null then customGuest
    else nixpkgs.lib.nixosSystem {
      system = guestSystem;
      modules = [
        (import ./guest.nix)
        ({ ... }: { venus.guest.enable = true; })
      ];
    };

  # Use the guest config's own pkgs so make-disk-image etc. inherit its
  # nixpkgs.config (e.g. mahmooz1's permittedInsecurePackages).
  guestPkgs      = nixosGuest.pkgs;
  guestKernel    = nixosGuest.config.system.build.kernel;
  # kernelFile is NixOS' own image name (aarch64 -> "Image").
  guestKernelImg = "${guestKernel}/${nixosGuest.config.system.boot.loader.kernelFile}";
  guestInitrd    = nixosGuest.config.system.build.initialRamdisk;
  guestToplevel  = nixosGuest.config.system.build.toplevel;

  # closureInfo passed via `regInfo=` on the kernel cmdline; the guest's
  # register-nix-paths service loads it into the local nix db on boot.
  # Embedded at the launcher (host) layer because referencing it from
  # the guest's own kernelParams would cycle through toplevel.
  guestClosureInfo = guestPkgs.closureInfo { rootPaths = [ guestToplevel ]; };

  # regInfo included so register-nix-paths can read it off the image.
  guestStorePaths = guestPkgs.closureInfo {
    rootPaths = [ guestToplevel guestClosureInfo ];
  };

  # qemu-vm.nix's useNixStoreImage; the tar half is
  # nixos/lib/erofs-store-image.nix verbatim, whose transform also strips
  # the ~nix~case~hack~N nix adds to paths colliding on a case-insensitive
  # host volume. sharing the host's live store over 9p instead wedges
  # every virtio device within a minute of any GL rendering. sqfstar not
  # upstream's mkfs.erofs, which ignores -z in --tar=f mode.
  mkStoreImage = ''
    ${hostPkgs.gnutar}/bin/tar --create \
      --absolute-names \
      --verbatim-files-from \
      --transform 'flags=rSh;s|/nix/store/||' \
      --transform 'flags=rSh;s|~nix~case~hack~[[:digit:]]\+||g' \
      --files-from ${guestStorePaths}/store-paths \
      | ${hostPkgs.squashfsTools}/bin/sqfstar \
        -quiet -no-progress -all-root -b 1048576 \
        ${if storeImageCompression == null
          then "-no-compression"
          else "-comp ${storeImageCompression}"} \
        "$STORE_IMG.tmp"
  '';

  # repack when either the closure or the compression choice changes.
  storeImageStamp = "${guestStorePaths} comp=${
    if storeImageCompression == null then "none" else storeImageCompression
  }";

  # 1 GiB ext4 seed (label=nixos), which the launcher resizes to 32G for
  # autoResize to grow into on boot. /nix/store rides on the store image
  # above, so this only holds /etc, /var, /home, ...
  guestImage = guestPkgs.runCommand "venus-guest-scratch" {
    nativeBuildInputs = [ guestPkgs.qemu-utils guestPkgs.e2fsprogs ];
  } ''
    mkdir -p "$out"
    truncate -s 1G raw.img
    mkfs.ext4 -F -L nixos -U random raw.img
    qemu-img convert -f raw -O qcow2 raw.img "$out/nixos.qcow2"
  '';

  # Binary name derives from the wrapped guest's hostname:
  #   mahmooz1 -> run-mahmooz1-vm  (matches the convention NixOS uses
  #   for system.build.vm, so this drops in as a replacement).
  launcherBaseName = "run-${nixosGuest.config.networking.hostName}-vm";

  # launcher         - foreground Cocoa window (cocoa-GL qemu).
  # launcher-console - serial console on the calling terminal, no
  #                    NSWindow (spice-IOSurface qemu). Ctrl-A X quits.
  mkLauncher = {
    name,
    qemu        ? hostPkgs.qemu-venus,
    consoleMode ? false,
  }: hostPkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ qemu hostPkgs.coreutils ];
    # gl=es args fool shellcheck into seeing comma array separators.
    excludeShellChecks = [ "SC2054" ];
    text = ''
      set -euo pipefail
      # VENUS_STATE_DIR gives a run its own disk/socket.
      CACHE="''${VENUS_STATE_DIR:-''${XDG_CACHE_HOME:-$HOME/.cache}/venus-guest}"
      mkdir -p "$CACHE"
      DISK="$CACHE/disk.qcow2"

      if [ ! -f "$DISK" ]; then
        echo "venus-guest: materialising writeable disk at $DISK"
        install -m 0644 "${guestImage}/nixos.qcow2" "$DISK"
        chmod u+w "$DISK"
        qemu-img resize "$DISK" 32G
      fi

      STORE_IMG="$CACHE/store.img"
      if [ "$(cat "$STORE_IMG.stamp" 2>/dev/null)" != "${storeImageStamp}" ]; then
        echo "venus-guest: packing nix store image (several minutes on a first run)"
        rm -f "$STORE_IMG" "$STORE_IMG.stamp" "$STORE_IMG.tmp"
        ${mkStoreImage}
        mv "$STORE_IMG.tmp" "$STORE_IMG"
        echo "${storeImageStamp}" > "$STORE_IMG.stamp"
      fi

      # MoltenVK ICD for virglrenderer's Vulkan loader; ANGLE on Metal
      # for IOSurface interop; DYLD_FALLBACK catches indirect dlopens
      # of ANGLE/MoltenVK by leaf name.
      export VK_DRIVER_FILES="${hostPkgs.moltenvk}/share/vulkan/icd.d/MoltenVK_icd.json"
      export VK_ICD_FILENAMES="$VK_DRIVER_FILES"
      export ANGLE_DEFAULT_PLATFORM=metal
      export DYLD_FALLBACK_LIBRARY_PATH="${hostPkgs.moltenvk}/lib:${hostPkgs.angle}/lib:''${DYLD_FALLBACK_LIBRARY_PATH:-/usr/local/lib:/usr/lib}"

      ${lib.optionalString consoleMode ''
        SPICE_SOCK="$CACHE/qemu.sock"
        rm -f "$SPICE_SOCK"
      ''}

      # VENUS_NET picks the backend per run, no rebuild needed:
      #   user  - slirp NAT, ssh on localhost:${toString sshHostPort}, unprivileged
      #   vmnet - Apple vmnet shared NAT, guest gets its own IP, needs root
      #   none  - no NIC at all
      NET="''${VENUS_NET:-${defaultNetwork}}"
      case "$NET" in
        user)
          NET_ARGS=(
            -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${toString sshHostPort}-:22"
            -device virtio-net-pci,netdev=net0
          )
          ;;
        vmnet)
          if [ "$(id -u)" -ne 0 ]; then
            echo "venus-guest: VENUS_NET=vmnet needs root (vmnet has no unprivileged path); re-run under sudo." >&2
            exit 1
          fi
          NET_ARGS=(
            -netdev vmnet-shared,id=net0
            -device virtio-net-pci,netdev=net0
          )
          ;;
        none)
          # Omitting -netdev entirely still gets a default slirp nic.
          NET_ARGS=( -nic none )
          ;;
        *)
          echo "venus-guest: unknown VENUS_NET=$NET (want user|vmnet|none)" >&2
          exit 1
          ;;
      esac

      QEMU_ARGS=(
        -name venus-guest
        -machine virt,gic-version=max,accel=hvf
        -cpu host -smp 4 -m 8G
        -kernel ${guestKernelImg}
        -initrd ${guestInitrd}/initrd
        -append "console=ttyAMA0,115200 root=/dev/vda init=${guestToplevel}/init regInfo=${guestClosureInfo}/registration loglevel=4"
        # Keeps block I/O off the main loop, which also serves 9p and the
        # net backend. `-drive if=virtio` tests the same, so this is
        # headroom rather than a fix.
        -object iothread,id=iothread0
        -blockdev driver=file,node-name=disk-file,filename="$DISK"
        -blockdev driver=qcow2,node-name=disk,file=disk-file
        -device virtio-blk-pci,drive=disk,iothread=iothread0
        # must stay after the root disk above so the guest sees it as vdb.
        -blockdev driver=file,node-name=store-file,filename="$STORE_IMG",read-only=on
        -blockdev driver=raw,node-name=store,file=store-file,read-only=on
        -device virtio-blk-pci,drive=store
        ${lib.optionalString (hostVoldir != null)
          "-virtfs local,path=${hostVoldir},security_model=none,mount_tag=host-data"}
        ${if consoleMode
          then ''-spice unix=on,addr="$SPICE_SOCK",disable-ticketing=on,gl=es''
          else ''-display cocoa,gl=es,zoom-to-fit=on,swap-opt-cmd=on''}
        -device virtio-gpu-gl-pci,hostmem=8G,blob=true,venus=true
        -device virtio-keyboard-pci
        -device virtio-tablet-pci
        "''${NET_ARGS[@]}"
        ${lib.optionalString consoleMode "-serial mon:stdio"}
      )

      ${lib.optionalString consoleMode ''
        echo "venus-guest: serial console attached.  Ctrl-A X to quit, Ctrl-A C for monitor."
      ''}
      exec qemu-system-aarch64 "''${QEMU_ARGS[@]}" "$@"
    '';
  };

  launcher = mkLauncher {
    name = launcherBaseName;
  };
  launcherConsole = mkLauncher {
    name        = "${launcherBaseName}-console";
    qemu        = hostPkgs.qemu-venus-spice;
    consoleMode = true;
  };

in {
  inherit hostPkgs nixosGuest;
  inherit guestImage guestKernel guestKernelImg guestInitrd guestToplevel;

  launchers = {
    launcher         = launcher;
    launcher-console = launcherConsole;
  };

  qemu-venus       = hostPkgs.qemu-venus;
  qemu-venus-spice = hostPkgs.qemu-venus-spice;
  virglrenderer    = hostPkgs.virglrenderer;
  libepoxy         = hostPkgs.libepoxy;
  moltenvk         = hostPkgs.moltenvk;
  vulkan-loader    = hostPkgs.vulkan-loader;
}
