{ pkgs, pinned-pkgs, ... }:
let
  mysbcl = (pinned-pkgs.sbcl.withPackages (ps: with ps; [
    serapeum
    lparallel
    cl-csv
    hunchentoot
    jsown
    alexandria
    cl-ppcre
    # swank
    slynk
    # nyxt
    cl-fad
    str
    py4cl # run python in common lisp
    # cl-cuda
    rutils # "radical" macros
    dexador # http library
    # numcl # numpy-like functionality
    clingon # command-line options parser
    cl-gtk4
  ]));
in rec {
  server_overlays = [
  ];

  server_packages = with pkgs; [
    pandoc
    imagemagickBig ghostscript # ghostscript is needed for some imagemagick commands
    ffmpeg-full.bin # untrunc-anthwlock
    sqlite
    silver-searcher
    rx
    jq
    ripgrep
    spotdl
    parallel
    pigz
    fd # alternative to find
    sshfs
    dash
    redis
    ncdu dua duf dust # file size checkers i think
    btop
    lshw
    lsof
    exiftool
    distrobox
    tree
    neovim
    eza
    tree-sitter
    goose-cli # goose ai tool
    glances

    openjdk
    gcc clang gdb clang-tools

    # networking tools
    curl wget nmap socat arp-scan tcpdump iftop
    inetutils # ncftp samba # samba4Full

    file vifm zip unzip fzf p7zip unrar-wrapper
    transmission_4 acpi gnupg lm_sensors
    cryptsetup
    openssl
    yt-dlp you-get
    aria # aria2c downloader
    pls # alternative to ls
    man-pages man-pages-posix
    ansible
    bc # for arithmetic in shell
    ttags
    diffsitter
    mongosh
    unison

    # some build systems
    cmake gnumake autoconf
    pkg-config

    # nodejs
    nodejs
    yarn

    # nix specific tools
    nixos-generators
    nix-prefetch-git
    deploy-rs
    nix-tree

    zeromq

    tesseract

    mysbcl

    # my_emacs
    # emacs
    # emacs-git
  ];

  main_server_ipv6 = "2a01:4f9:c012:ad1b::1";
  main_server_user = "mahmooz";
  main_server_ip = "95.217.15.125";
  main_user = "mahmooz";
  home_dir = "/home/mahmooz";
  work_dir = "/home/${main_user}/work";
  scripts_dir = "${work_dir}/scripts";
  dotfiles_dir = "${work_dir}/otherdots";
  blog_dir = "${work_dir}/blog";
  brain_dir = "${home_dir}/brain";
  music_dir = "${home_dir}/music";
  notes_dir = "${brain_dir}/notes";
  data_dir = "${home_dir}/data";
  mpv_socket_dir = "${data_dir}/mpv_data/sockets";
  mpv_main_socket_path = "${data_dir}/mpv_data/sockets/mpv.socket";
  personal_website = "https://mahmoodsh36.github.io";
  mygithub = "https://github.com/mahmoodsh36";
  main_key = "${brain_dir}/keys/hetzner1";
}