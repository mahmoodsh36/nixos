{ pkgs, pinned-pkgs, ... }:
let
  mysbcl = (pinned-pkgs.sbcl.withPackages (ps: with ps; [
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
  ]));
  constants = (import ./constants.nix);
in rec {
  server_overlays = [
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

    # networking tools
    curl wget nmap socat arp-scan tcpdump iftop
    inetutils rclone sshfs

    file zip unzip fzf p7zip unrar-wrapper
    transmission_4 acpi gnupg lm_sensors
    cryptsetup openssl
    yt-dlp you-get aria
    man-pages man-pages-posix

    # some build systems
    cmake gnumake autoconf
    pkg-config

    openjdk

    # nix specific tools
    nixos-generators
    nix-prefetch-git
    nix-tree
    mysbcl
    steam-run-free
    nixos-anywhere

    # ai stuff?
    python3Packages.huggingface-hub
    aider-chat
    # pinned-pkgs.goose-cli # goose ai tool
  ];

  home_dir = "/home/${constants.myuser}";
  work_dir = "/home/${constants.myuser}/work";
  scripts_dir = "${work_dir}/scripts";
  dotfiles_dir = "${work_dir}/otherdots";
  nix_config_dir = "${work_dir}/nixos/";
  blog_dir = "${work_dir}/blog";
  brain_dir = "${home_dir}/brain";
  music_dir = "${home_dir}/music";
  notes_dir = "${brain_dir}/notes";
  data_dir = "${home_dir}/data";
  models_dir = "${home_dir}/mnt2/my/models";
  mpv_socket_dir = "${data_dir}/mpv_data/sockets";
  mpv_main_socket_path = "${data_dir}/mpv_data/sockets/mpv.socket";
  main_key = "${brain_dir}/keys/hetzner1";
}