{ pkgs, pkgs-pinned, inputs, ... }:
let
  mysbcl = (pkgs-pinned.sbcl.withPackages (ps: with ps; [
    inputs.cltpt.packages.${pkgs.system}.cltpt-lib
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
    cl-json
  ]));
in rec {
  server_overlays = [
    inputs.nix-alien.overlays.default
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
    devenv
    podman-compose
    sbcl.pkgs.qlot-cli
    ytdl-sub yt-dlp
    # (yt-dlp.overrideAttrs (finalAttrs: prevAttrs: {
    #   src = pkgs.fetchFromGitHub {
    #     owner = "yt-dlp";
    #     repo = "yt-dlp";
    #     rev = "a03c37b44ec8f50fd472c409115096f92410346d";
    #     sha256 = "sha256-7scolIsUsMfPtKg/OYcm7hWAZmnlFe901sfw6tGO2Wk=";
    #   };
    # }))
    nethogs
    inputs.cltpt.packages.${pkgs.system}.default

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
    inputs.disko.packages.${pkgs.system}.default
  ];
}