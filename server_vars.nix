{ pkgs, pkgs-pinned, inputs, ... }:
let
  # cltpt = pkgs-pinned.sbcl.buildASDFSystem rec {
  #   pname = "cltpt";
  #   version = "0.1";
  #   src = pkgs.fetchFromGitHub {
  #     owner = "mahmoodsh36";
  #     repo = "cltpt";
  #     rev = "37ede3f4f36c130ac674232876bd07956ab968aa";
  #     sha256 = "sha256-Edxc99oVJEDApOObfSkUIggUolxdg2ipkAo2FkhlSZs=";
  #   };
  #   systems = [ "cltpt" ];
  #   lispLibs = with pkgs-pinned.sbcl.pkgs; [
  #     clingon
  #     ironclad
  #     fiveam
  #     # uiop
  #     str
  #     cl-fad
  #     cl-ppcre
  #   ];
  # };
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
    closer-mop
    local-time
  ]));
  constants = (import ./constants.nix);
in rec {
  server_overlays = [
    inputs.nix-alien.overlays.default
    # (final: prev:
    #   {
    #     sbcl = mysbcl;
    #   }
    # )
  ];

  server_packages = with pkgs; [
    sqlite
    jq
    ripgrep
    parallel
    fd # alternative to find
    dash
    lshw lsof tree
    neovim tree-sitter
    glances btop ncdu
    gcc clang gdb clang-tools
    file zip unzip fzf p7zip unrar-wrapper
    gnupg
    openssl
    man-pages man-pages-posix
    wezterm # we need it installed on the server too, for persistent sessions
    fdupes
    libva-utils
    jellyfin-web jellyfin-ffmpeg jellyfin
    miller
    bc # used for some arithmetic in shell scripts
    postgresql

    podman-compose

    # networking tools
    curl wget nmap socat arp-scan tcpdump iftop
    inetutils rclone sshfs bind

    # some build systems
    cmake gnumake autoconf
    pkg-config

    # nix specific stuff
    mysbcl
    compose2nix
    nvfetcher
    arion
  ];
}