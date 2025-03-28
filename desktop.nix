{ config, pkgs, lib, inputs, pinned-pkgs, ... }:

let
  server_vars = (import ./server_vars.nix { pkgs = pkgs; pinned-pkgs = pinned-pkgs; });
  desktop_vars = (import ./desktop_vars.nix { pkgs = pkgs; pinned-pkgs = pinned-pkgs; });
  per_machine_vars = (import ./per_machine_vars.nix {});
  mypython = desktop_vars.desktop_python;
  # packages i dont think i need..
  other_packages = with pkgs; [
    stremio
    syncthing
    hoarder # wallabag
    prettierd # for emacs apheleia
    nodePackages.prettier # for emacs apheleia
    black
    gnuplot
    lean
    maxima
    kaggle google-cloud-sdk python3Packages.datasets
    (lua.withPackages(ps: with ps; [ busted luafilesystem luarocks ]))
    rustc meson ninja
    typescript
    tailwindcss
    poetry
    neo4j
    bun
    # lisps
    babashka
    chicken
    guile
    racket
    devdocs-desktop # offline docs
    # lsp
    haskell-language-server emmet-language-server clojure-lsp llm-ls
    nodePackages.node2nix yaml-language-server postgres-lsp ansible-language-server
    asm-lsp htmx-lsp lua-language-server java-language-server typst-lsp
    tailwindcss-language-server
    texlab
    sqls
    ruff-lsp
    nodePackages_latest.typescript-language-server
    zoom-us # do i realy want this running natively?
    hugo
    sass
    subversion # git alternative
    squeekboard
    flameshot # screenshot util?
    wofi # dmenu-like for wayland
    eww # widgets..
    zenity # gui interfaces from scripts?
    hyprpicker
    swappy # for quick snapshot image editing
    sshpass
    kitty
    brave tor-browser-bundle-bin google-chrome
    jellyfin jellyfin-web jellyfin-ffmpeg jellyfin-media-player jellycli jellyfin-mpv-shim
    djvulibre
    krita
    youtube-music
    telegram-desktop
    vlc
    silver-searcher
    redis
    dua duf dust # file size checkers i think
    distrobox
    eza
    ncftp samba
    vifm
    pls # alternative to ls
    ansible
    bc # for arithmetic in shell
    ttags
    diffsitter
    mongosh
    unison
    nodejs yarn
    deploy-rs
    zeromq
    tesseract
    djvu2pdf fntsample calibre
    lollypop clementine
  ];
  # turn off all rgb coloring?
  no-rgb = pkgs.writeScriptBin "no-rgb" ''
    #!/bin/sh
    NUM_DEVICES=$(${pkgs.openrgb}/bin/openrgb --noautoconnect --list-devices | grep -E '^[0-9]+: ' | wc -l)

    for i in $(seq 0 $(($NUM_DEVICES - 1))); do
      ${pkgs.openrgb}/bin/openrgb --noautoconnect --device $i --mode static --color 000000
    done
  '';
in
{
  imports = [
    ./server.nix
  ] ++ lib.optional (per_machine_vars.enable_nvidia) ./nvidia.nix;

  boot.kernelParams = [
    "quiet"
    "splash"
    "boot.shell_on_fail"
    "usbcore.autosuspend=-1" # or 120 to wait two minutes, etc
  ];

  # turn off all rgb coloring?
  services.udev.packages = [ pkgs.openrgb ];
  boot.kernelModules = [ "i2c-dev" ];
  hardware.i2c.enable = true;
  systemd.services.no-rgb = {
    description = "no-rgb";
    serviceConfig = {
      ExecStart = "${no-rgb}/bin/no-rgb";
      Type = "oneshot";
    };
    wantedBy = [ "multi-user.target" ];
  };

  # better safe than sorry (for having to deal with firmware/driver issues)..?
  hardware.enableAllHardware = true;
  hardware.enableAllFirmware = true;

  # for firmware updates
  services.fwupd.enable = true;

  # automatic screen rotation?
  hardware.sensor.iio.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.nvidia.open = false;

  # vaapi (accelerated video playback), enable vaapi on OS-level
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };
  hardware.graphics = {
    # accelerated video playback
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiVdpau
      intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
      vpl-gpu-rt # QSV on 11th gen or newer
      intel-media-sdk # QSV up to 11th gen
    ];
  };

  # enable sound and bluetooth
  # services.blueman.enable = true;
  hardware.bluetooth = {
    enable = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
      Policy = {
        AutoEnable = "true";
      };
    };
    powerOnBoot = true;
  };
  security.rtkit.enable = true; # realtime audio support
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  systemd.user.services.mpris-proxy = {
    description = "mpris proxy";
    after = [ "network.target" "sound.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
  };

  # my overlays
  nixpkgs.overlays = [
  ] ++ server_vars.server_overlays;

  # graphical stuff (wayland,x11,etc)
  services.xserver.xkb.layout = "us,il,ara";
  services.libinput = {
    enable = true;
    touchpad = {
      disableWhileTyping = true;
      tappingDragLock = false;
      accelSpeed = "0.9";
      naturalScrolling = false;
    };
  };
  # programs.hyprland = {
  #   enable = true;
  #   package = pkgs.hyprland;
  #   xwayland.enable = true;
  # };
  xdg.portal = {
    # xdgOpenUsePortal = true; # this seems to override my .desktop definitions in home-manager?
    enable = true;
    extraPortals = [
      # pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
      # pkgs.xdg-desktop-portal-kde
      pkgs.xdg-desktop-portal-wlr
    ];
    config.hyprland = {
      default = [
        "wlr"
        "gtk"
      ];
    };
  };

  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "mahmooz";
    };
    # sddm.enable = true;
    # sddm.wayland.enable = true;
    # sddm.enableHidpi = true;
    # defaultSession = "hyprland";
    # defaultSession = "gnome";
    # defaultSession = "plasma";
  };

  # tty configs
  console = {
    #earlySetup = true;
    font = "ter-i14b";
    packages = with pkgs; [ terminus_font ];
    useXkbConfig = true; # remap caps to escape
  };
  security.audit.enable = true;
  security.auditd.enable = true;

  # ask for password in terminal instead of x11-ash-askpass
  programs.ssh.askPassword = "";

  # enable some programs/services
  services.printing.enable = true; # CUPS
  services.touchegg.enable = true;
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-media-tags-plugin
      thunar-volman
    ];
  };
  programs.xfconf.enable = true;
  programs.dconf.enable = true;
  services.tumbler.enable = lib.mkForce false;
  programs.light.enable = true;

  # hybrid sleep when press power button
  services.logind.extraConfig = ''
    HandlePowerKey=ignore
    IdleAction=ignore
    IdleActionSec=1m
  '';
  # dont hibernate when lid is closed
  # services.logind.lidSwitch = "ignore";

  # virtualization
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      ovmf = {
        enable = true;
        packages = with pkgs; [ OVMFFull.fd ];
      };
      swtpm.enable = true;
    };
  };
  programs.virt-manager.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      fantasque-sans-mono
      google-fonts
      cascadia-code
      nerd-fonts.inconsolata nerd-fonts.jetbrains-mono nerd-fonts.fira-code nerd-fonts.iosevka
      iosevka
      fira-code
      ubuntu_font_family
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      dejavu_fonts
      cm_unicode
      unicode-emoji
      unicode-character-database
      unifont
      symbola
      # persian font
      vazir-fonts
      font-awesome
      corefonts # for good arabic/hebrew/etc fonts
      mplus-outline-fonts.githubRelease
      dina-font
      proggyfonts
      monaspace
    ];
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    fontconfig = {
      enable = true;
      antialias = true;
      cache32Bit = true;
      hinting.autohint = true;
      hinting.enable = true;
    };
  };

  # dictionaries
  services.dictd.enable = true;
  services.dictd.DBs = with pkgs.dictdDBs; [ wiktionary wordnet ];
  environment.wordlist.enable = true;

  documentation.dev.enable = true;

  programs.nix-ld = {
    enable = true;
    libraries = [
      pkgs.stdenv.cc.cc
      pkgs.zlib
      pkgs.fuse3
      pkgs.icu
      pkgs.nss
      pkgs.openssl
      pkgs.curl
      pkgs.expat
      pkgs.xorg.libX11
      pkgs.vulkan-headers
      pkgs.vulkan-loader
      pkgs.vulkan-tools
    ];
  };

  # packages
  environment.systemPackages = with pkgs; [
    (pkgs.writeShellScriptBin "python" ''
      export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
      exec ${mypython}/bin/python "$@"
    '')
    (pkgs.writeShellScriptBin "python3" ''
      export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
      exec ${mypython}/bin/python "$@"
    '')

    # overwrite notify-send to not let anything handle notifications
    (pkgs.writeShellScriptBin "notify-send" ''
      echo $@ > /tmp/notif
    '')

    (pkgs.writeShellScriptBin "julia" ''
      export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
        pkgs.stdenv.cc.cc.lib
        pkgs.libGL
        pkgs.glib
        pkgs.zlib
      ]}:$LD_LIBRARY_PATH
      export DISPLAY=:0 # cheating so it can compile
      exec ${julia}/bin/julia "$@"
    '')

    inputs.lem.packages.${pkgs.system}.lem-sdl2

    # media tools
    mpv
    # feh # image viewer (can it set wallpaper on wayland?)
    kdePackages.okular zathura foliate mupdf
    xournalpp # rnote krita
    ocrmypdf pdftk pdfgrep poppler_utils
    imv # nice image viewer
    spotube # open source spotify client?
    inkscape

    # general tools
    scrcpy
    pavucontrol
    libreoffice
    neovide

    # commandline tools
    wezterm
    pulsemixer # tui for pulseaudio control
    alsa-utils
    playerctl # media control
    gptfdisk parted
    libtool # to compile vterm
    btrfs-progs

    # wayland
    wl-clipboard
    grim slurp # for screenshots
    brightnessctl
    wf-recorder
    iio-hyprland
    wvkbd # onboard alternative (on-screen keyboard)
    wl-screenrec
    libnotify
    darktable # image editor
    digikam # another image viewer?
    swww # wallpaper setter

    vdhcoapp # for firefox video download helper

    # other
    adb-sync
    woeusb-ng
    ntfs3g
    gnupg
    simplescreenrecorder
    usbutils
    pciutils
    graphviz
    isync
    notmuch
    monolith # save webpages
    liquidctl
    libinput
    bluez-tools blueman
    pulseaudioFull
    # pinned-pkgs.open-webui
    quickemu # quickly start VMs
    zeal dasht
    material-design-icons
    floorp

    # sageWithDoc
    pinned-pkgs.sage pinned-pkgs.sagetex

    # some programming languages/environments
    texlive.combined.scheme-full
    # desktop_vars.desktop_julia
    # julia
    typst

    # lsp
    cmake-language-server
    nodePackages.bash-language-server
    nil
    python3Packages.python-lsp-server
    vscode-langservers-extracted

    # dictionary
    (aspellWithDicts (dicts: with dicts; [ en en-computers en-science ]))

    # for widgets
    (pinned-pkgs.python3Packages.buildPythonPackage rec {
      pname = "widgets";
      format = "other";
      version = "1.0";
      dontBuild = true;
      dontUnpack = true;

      src = /home/mahmooz/work/widgets;

      nativeBuildInputs = with pinned-pkgs; [ gobject-introspection ];
      buildInputs = with pinned-pkgs; [ gtk3 gtk-layer-shell wrapGAppsHook ];
      propagatedBuildInputs = with pinned-pkgs.python3Packages; [
        pydbus
        pygobject3
      ];

      installPhase = ''
        mkdir -p $out/bin
        cp ${src}/*.py $out/bin/
        cp ${src}/main.css $out/bin/
        chmod +x $out/bin/*.py
      '';
    })
  ]
  ++ server_vars.server_packages
  ++ (pkgs.lib.optionals per_machine_vars.enable_nvidia [
    cudatoolkit nvtopPackages.full llama-cpp
  ]);

  systemd.services.my_mpv_logger_service = {
    description = "mpv logger";
    wantedBy = [ "multi-user.target" ];
    script = "${pkgs.dash}/bin/dash ${server_vars.scripts_dir}/mpv_logger.sh";
    serviceConfig = {
      User = "mahmooz";
      Restart = "always";
      RuntimeMaxSec = "3600";
      # ExecStart = "${pkgs.coreutils}/bin/sh ${server_vars.scripts_dir}/mpv_logger.sh";
    };
  };

  services.ollama = {
    enable = per_machine_vars.enable_nvidia;
    package = pkgs.ollama-cuda;
    acceleration = "cuda";
    host = "0.0.0.0";
  };

  systemd.services.my_keys_py_service = {
    description = "service for keys.py";
    wantedBy = [ "multi-user.target" ];
    # run it with a shell so it has access to all binaries as usual in $PATH
    script = "${pkgs.zsh}/bin/zsh -c '${mypython}/bin/python /home/mahmooz/work/keys/keys.py -d'";
    serviceConfig = {
      # User = "mahmooz";
      Restart = "always";
    };
  };

  # without this okular is blurry
  environment.sessionVariables.QT_QPA_PLATFORM = "wayland";

  qt = {
    enable = true;
    platformTheme = "qt5ct";
    style = "adwaita-dark";
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="block", ENV{ID_FS_UUID}=="777ddbd7-9692-45fb-977e-0d6678a4a213", RUN+="${pkgs.coreutils}/bin/mkdir -p /home/mahmooz/mnt" RUN+="${pkgs.systemd}/bin/systemd-mount $env{DEVNAME} /home/mahmooz/mnt/", RUN+="${lib.getExe pkgs.logger} --tag my-manual-usb-mount udev rule success, drive: %k with uuid $env{ID_FS_UUID}"
    SUBSYSTEM=="block", ENV{ID_FS_UUID}=="be5af23f-da6d-42ee-a346-5ad3af1a299a", RUN+="${pkgs.coreutils}/bin/mkdir -p /home/mahmooz/mnt2" RUN+="${pkgs.systemd}/bin/systemd-mount $env{DEVNAME} /home/mahmooz/mnt2", RUN+="${lib.getExe pkgs.logger} --tag my-manual-usb-mount udev rule success, drive: %k with uuid $env{ID_FS_UUID}"
  '';
}