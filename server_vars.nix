{ pkgs, pkgs-pinned, inputs, ... }:
let
  cltpt = pkgs-pinned.sbcl.buildASDFSystem rec {
    pname = "cltpt";
    version = "0.1";
    src = pkgs.fetchFromGitHub {
      owner = "mahmoodsh36";
      repo = "cltpt";
      rev = "9961bcd8276b03d150b96f973b8f484d1700e185";
      sha256 = "sha256-08MfeUV90OpBoI9mqQYXTapu3D4/3pn0SNxFwTOayeg=";
    };
    systems = [ "cltpt" ];
    lispLibs = with pkgs-pinned.sbcl.pkgs; [
      clingon
      ironclad
      fiveam
      # uiop
      str
      cl-fad
      cl-ppcre
      local-time
    ];
  };
  mysbcl = (pkgs-pinned.sbcl.withPackages (ps: with ps; [
    cltpt
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
    (pkgs.callPackage ./vend.nix {})
    devenv
    podman-compose
    sbcl.pkgs.qlot-cli

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