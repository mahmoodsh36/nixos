{ pkgs, pkgs-pinned, inputs, ... }:
let
  mysbcl = (pkgs-pinned.sbcl.withPackages (ps: with ps; [
    serapeum
    lparallel
    cl-csv
    jsown
    alexandria
    cl-ppcre
    # swank
    slynk
    cl-fad
    str
    py4cl # run python in common lisp
    cl-cuda
    clingon # command-line options parser
    ironclad # crypto functions
    fiveam # tests
  ]));
  constants = (import ./constants.nix);
in rec {
  server_overlays = [
    inputs.nix-alien.overlays.default
  ];

  server_packages = with pkgs; [
    pandoc
    imagemagickBig ghostscript # ghostscript is needed for some imagemagick commands
    ffmpeg-full.bin # untrunc-anthwlock
    sqlite
    jq
    ripgrep
    parallel
    pigz # for compression
    fd # alternative to find
    dash
    lshw lsof tree
    exiftool
    neovim tree-sitter
    glances btop ncdu
    spotdl
    gcc clang gdb clang-tools
    openjdk
    file zip unzip fzf p7zip unrar-wrapper
    transmission_4 acpi gnupg lm_sensors
    cryptsetup openssl
    yt-dlp you-get aria
    man-pages man-pages-posix
    wezterm # we need it installed on the server too, for persistent sessions
    nodejs
    python3Packages.playwright playwright playwright-test
    uv # rustc cargo
    argc

    # networking tools
    curl wget nmap socat arp-scan tcpdump iftop
    inetutils rclone sshfs bind

    # some build systems
    cmake gnumake autoconf
    pkg-config

    # nix specific stuff
    nixos-generators
    nix-prefetch-git
    nix-tree
    mysbcl
    steam-run-free
    nixos-anywhere
    nix-init

    # ai stuff?
    python3Packages.huggingface-hub
    aider-chat
    pkgs-pinned.goose-cli # goose ai tool
  ];
}