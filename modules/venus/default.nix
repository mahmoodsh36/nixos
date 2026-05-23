# Venus GPU passthrough host-side machinery: aarch64-linux NixOS guest
# with Venus -> Metal passthrough on an aarch64-darwin host, built from
# UTM's macOS-Venus tree.
#
# Produces aarch64-linux derivations (guest kernel, initrd, qcow2) that
# can't build natively on darwin; needs a remote builder or
# nix.linux-builder.

{ nixpkgs
, hostSystem ? "aarch64-darwin"
, guestSystem ? "aarch64-linux"
, lib ? nixpkgs.lib
# An externally-built nixosSystem to boot as the guest (e.g. mahmooz1
# extended with the venus-guest module). When null, builds the stub
# guest in ./guest.nix.
, customGuest ? null
}:

let
  sources = {
    # utmapp/virglrenderer @ branch macos (osy's open virgl MRs).
    virglrenderer = {
      rev  = "d48a2d0d9a722fffd3f92c83e71d9426a4892a66";
      hash = "sha256-8NSYebv9iKynkbGl7Jh8J0a7A0TC1+IP1Ff8B2zNnd4=";
    };

    # utmapp/libepoxy @ branch macos-venus. Stock nixpkgs libepoxy
    # disables EGL on darwin; this branch wires up ANGLE.
    libepoxy = {
      rev  = "5014658f79e4d6872a1ad6754da9098ccd9d4fc5";
      hash = "sha256-XV7RNGev2UJLZ5o8Cqq/a4ydxRMtWxUIpSnORabvBrk=";
    };

    # utmapp/MoltenVK @ branch macos, 3 fixes ahead of Khronos needed
    # for stable Venus-on-Metal interop.
    moltenvk = {
      rev  = "6f2002d1a583c3347827cbce1c1b8a33aeec2077";
      hash = "sha256-wYBRMscfiyrKpqjoyGTJ6ukhTLTNlkSvJ/h1kfTxl3Q=";
    };

    # Guest Mesa hack: round virtio-gpu blob mappings up to 16 KiB to
    # match the host's Apple-Silicon page size. Obsolete once drm/virtio
    # F_BLOB_ALIGNMENT lands.
    mesa16kAlign = {
      url  = "https://gist.githubusercontent.com/osy/a8f705050eed1c8421ad1a0855a8faa9/raw/1080c476b50ac1ec379def46ba9d78561e582635/0001-DO-NOT-MERGE-venus-hack-to-align-mappings-to-16KiB.patch";
      hash = "sha256-DbitYq+/wl5SSHk+jeIcTvReZZ3Vojx5alicYShC/qU=";
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

  guestOverlay = final: prev: {
    mesa = prev.mesa.overrideAttrs (old: {
      patches = (old.patches or []) ++ [
        (final.fetchurl {
          name = "mesa-venus-16k-blob-align.patch";
          url  = sources.mesa16kAlign.url;
          hash = sources.mesa16kAlign.hash;
        })
      ];
    });

    # nihui/vkpeak - pure-compute Vulkan benchmark. Definitive check
    # that Venus dispatches run on the GPU (llvmpipe: MFLOPS, real HW:
    # TFLOPS).
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
      # Upstream cmake has no install rule for the binary; copy by hand.
      installPhase = ''
        runHook preInstall
        install -Dm755 vkpeak "$out/bin/vkpeak"
        runHook postInstall
      '';
    };
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
  guestKernelImg = "${guestKernel}/${guestPkgs.stdenv.hostPlatform.linux-kernel.target}";
  guestInitrd    = nixosGuest.config.system.build.initialRamdisk;
  guestToplevel  = nixosGuest.config.system.build.toplevel;

  # Empty 1 GiB ext4 scratch disk, label="nixos". /nix/store is shared
  # from the host over 9p (see -virtfs in mkLauncher), so this only holds
  # the writable tree (/etc, /var, /home, ...). mkfs runs unprivileged
  # against a regular file and is deterministic.
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
      CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/venus-guest"
      mkdir -p "$CACHE"
      DISK="$CACHE/disk.qcow2"

      if [ ! -f "$DISK" ]; then
        echo "venus-guest: materialising writeable disk at $DISK"
        install -m 0644 "${guestImage}/nixos.qcow2" "$DISK"
        chmod u+w "$DISK"
        qemu-img resize "$DISK" 32G
      fi

      # VK_DRIVER_FILES: Metal-backed Vulkan ICD for virglrenderer's loader.
      # ANGLE_DEFAULT_PLATFORM=metal: force ANGLE onto Metal for IOSurface
      #   interop (not its GL/Vulkan backends).
      # DYLD_FALLBACK_LIBRARY_PATH: catch any indirect dlopen of ANGLE /
      #   MoltenVK by leaf name.
      export VK_DRIVER_FILES="${hostPkgs.moltenvk}/share/vulkan/icd.d/MoltenVK_icd.json"
      export VK_ICD_FILENAMES="$VK_DRIVER_FILES"
      export ANGLE_DEFAULT_PLATFORM=metal
      export DYLD_FALLBACK_LIBRARY_PATH="${hostPkgs.moltenvk}/lib:${hostPkgs.angle}/lib:''${DYLD_FALLBACK_LIBRARY_PATH:-/usr/local/lib:/usr/lib}"

    '' + (if consoleMode then ''
      SPICE_SOCK="$CACHE/qemu.sock"
      rm -f "$SPICE_SOCK"
    '' else "") + ''

      QEMU_ARGS=(
        -name venus-guest
        -machine virt,gic-version=max,accel=hvf
        -cpu host -smp 4 -m 8G
        -kernel ${guestKernelImg}
        -initrd ${guestInitrd}/initrd
        -append "console=ttyAMA0,115200 root=/dev/vda init=${guestToplevel}/init loglevel=4"
        -drive if=virtio,format=qcow2,file="$DISK"
        # Share host /nix/store over 9p so we don't bake the ~63 GB
        # closure into the disk; guest enforces readonly again.
        -virtfs local,path=/nix/store,security_model=none,mount_tag=nix-store,readonly=on
        ${if consoleMode
          then ''-spice unix=on,addr="$SPICE_SOCK",disable-ticketing=on,gl=es''
          else ''-display cocoa,gl=es,zoom-to-fit=on''}
        -device virtio-gpu-gl-pci,hostmem=8G,blob=true,venus=true
        -device virtio-keyboard-pci
        -device virtio-tablet-pci
        # No networking: slirp virtio-net runs in QEMU's main loop and
        # tx-times-out under load on darwin, starving 9p + virtio-blk
        # until jbd2/journald wedge. -nic none is required because
        # omitting -netdev still gets a default -net nic -net user.
        -nic none
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
