{ stdenv, lib, pkgs, fetchurl, ... }:

stdenv.mkDerivation rec {
  pname = "qemu-darwin-opengl";
  version = "9.1.1";

  src = fetchurl {
    url = "https://download.qemu.org/qemu-${version}.tar.xz";
    hash = "sha256-fcD52lSR/0SVAPMxAGOja2GfI27kVwb9CEbrN9S7qIk=";
  };

  nativeBuildInputs = with pkgs; [
    pkg-config
    ninja
    python3
    meson
  ];

  buildInputs = with pkgs; [
    dtc
    glib
    libslirp
    pixman
    darwin.sigtool
    # macOS OpenGL support
    libepoxy
    virglrenderer
    # Python dependencies for QEMU build
    python3Packages.distlib
  ];

  dontUseMesonConfigure = true;
  dontStrip = true;

  postPatch = ''
    # Replace entitlement.sh with a no-op stub (macOS tools aren't available in Nix)
    cat > scripts/entitlement.sh << 'EOF'
#!/bin/sh
# Stub - macOS entitlement tools (Rez, SetFile) aren't available in Nix
exit 0
EOF
    chmod +x scripts/entitlement.sh
  '';

  configureFlags = [
    "--disable-strip"
    "--target-list=aarch64-softmmu,x86_64-softmmu"
    "--disable-dbus-display"
    "--disable-plugins"
    "--enable-slirp"
    "--enable-tcg"
    "--enable-virtfs"
    # macOS specific
    "--enable-cocoa"
    "--enable-hvf"
    # GPU acceleration with virglrenderer (OpenGL not needed/available on macOS)
    "--enable-virglrenderer"
  ];

  preBuild = ''
    cd build
  '';

  postInstall = ''
    # The entitlement script normally copies -unsigned binaries to final names
    # Since we stubbed it out, do this manually
    for f in $out/bin/*-unsigned; do
      if [ -f "$f" ]; then
        cp "$f" "''${f%-unsigned}"
      fi
    done

    # Sign binaries with Hypervisor Framework entitlements
    # This is required for HVF acceleration on macOS
    cat > entitlements.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.hypervisor</key>
    <true/>
</dict>
</plist>
EOF

    # Sign each qemu-system binary
    for binary in $out/bin/qemu-system-*; do
      if [ -f "$binary" ] && [ ! -L "$binary" ]; then
        codesign --force --sign - --entitlements entitlements.plist "$binary" || true
      fi
    done
  '';

  env.NIX_CFLAGS_COMPILE = "-Wno-error=implicit-function-declaration";

  meta = with lib; {
    description = "QEMU with OpenGL/virgl support for macOS";
    platforms = platforms.darwin;
    license = licenses.gpl2Plus;
  };
}
