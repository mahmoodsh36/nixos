{ config, pkgs, lib, inputs, ... }:

let
  server_vars = (import ./server_vars.nix { pkgs = pkgs; });
  desktop_vars = (import ./desktop_vars.nix { pkgs = pkgs; });
  per_machine_vars = (import ./per_machine_vars.nix {});
  mypython = pkgs.python3.withPackages(ps: with ps; [
    python-magic
    requests
    paramiko pynacl # for find_computers.py (latter is needed for former)

    # for quick tests etc? i use it for ML uni courses
    matplotlib
    numpy

    evdev # for event handling/manipulation

    # for other system scripts?
    pyzmq

    # for widgets, doesnt work
    # pygobject3
    # pydbus
  ]);
in
{
  imports = [
    ./server.nix
  ] ++ lib.optional (per_machine_vars.enable_nvidia) ./nvidia.nix;

  # automatic screen rotation?
  hardware.sensor.iio.enable = true;

  # iptsd
  # services.iptsd.enable = true;
  # services.iptsd.config.Touchscreen.DisableOnStylus = true;
  # services.iptsd.config.Touchscreen.DisableOnPalm = true;

  # i dont need this to use wacom, but it provides extra options/features
  # hardware.opentabletdriver = {
  #   enable = true;
  #   daemon.enable = true;
  # };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;

  };
  hardware.nvidia.open = false;

  # vaapi (accelerated video playback)
  # enable vaapi on OS-level
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
  # services.pipewire.enable = lib.mkForce false;
  # hardware.pulseaudio = {
  #   enable = true;
  #   # extraModules = [ pkgs.pulseaudio-modules-bt ];
  #   package = pkgs.pulseaudioFull;
  #   extraConfig = "
  #     load-module module-switch-on-connect
  #   ";
  # };
  systemd.user.services.mpris-proxy = {
    description = "mpris proxy";
    after = [ "network.target" "sound.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
  };

  nixpkgs.config.cudaSupport = per_machine_vars.enable_nvidia;

  # my overlays
  nixpkgs.overlays = [
    (self: super:
    {
      llama-cpp = super.llama-cpp.overrideAttrs (oldAttrs: rec {
        src = super.fetchFromGitHub {
          owner = "ggerganov";
          repo = "llama.cpp";
          rev = "a94f3b2727e97eb6c904006eb786960c069282bc";
          sha256 = "06canqysnbk1030dzjailcx272qyfg1rnzpgnz2x104zi2c2n9cc";
        };
      });
    })
    (self: super:
    {
      my_sxiv = super.sxiv.overrideAttrs (oldAttrs: rec {
        src = super.fetchFromGitHub {
          owner = "mahmoodsheikh36";
          repo = "sxiv";
          rev = "e10d3683bf9b26f514763408c86004a6593a2b66";
          sha256 = "161l59balzh3q8vlya1rs8g97s5s8mwc5lfspxcb2sv83d35410a";
        };
      });
    })
    (self: super:
    {
      my_awesome = super.awesome.overrideAttrs (oldAttrs: rec {
        postPatch = ''
          patchShebangs tests/examples/_postprocess.lua
        '';
        patches = [];
        src = super.fetchFromGitHub {
          owner = "awesomeWM";
          repo = "awesome";
          rev = "7ed4dd620bc73ba87a1f88e6f126aed348f94458";
          sha256 = "0qz21z3idimw1hlmr23ffl0iwr7128wywjcygss6phyhq5zn5bx3";
        };
      });
    })
    # is this needed anymore?
    # (final: prev: { cudaPackages = final.cudaPackages_12_3; })
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
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
  };
  xdg.portal = {
    # xdgOpenUsePortal = true; # this seems to override my .desktop definitions in home-manager?
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
      # pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-kde
      pkgs.xdg-desktop-portal-wlr
    ];
    config.hyprland = {
      default = [
        "wlr"
        "gtk"
      ];
    };
  };

  # kde
  # services.xserver.desktopManager.plasma6.enable = true;
  # environment = {
  #   etc."xdg/baloofilerc".source = (pkgs.formats.ini {}).generate "baloorc" {
  #     "Basic Settings" = {
  #       "Indexing-Enabled" = false;
  #     };
  #   };
  # };

  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "mahmooz";
    };
    sddm.enable = true;
    sddm.wayland.enable = true;
    sddm.enableHidpi = true;
    # defaultSession = "none+awesome";
    # defaultSession = "xfce+awesome";
    # defaultSession = "xfce";
    defaultSession = "hyprland";
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

  # allow the user run a program to poweroff the system.
  security.polkit = {
    enable = true;
    extraConfig = ''
      polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" ||
              action.id == "org.freedesktop.systemd1.manage-unit-files") {
              if (action.lookup("unit") == "poweroff.target") {
                  return polkit.Result.YES;
              }
          }
      });
    '';
  };

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
  # programs.xfconf.enable = true;
  # programs.nm-applet.enable = true; # this thing is annoying lol (send notifications and stuff..)
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
  # virtualisation.waydroid.enable = true;
  # virtualisation.virtualbox.host.enable = true;
  # virtualisation.virtualbox.host.enableExtensionPack = true;
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
      nerd-fonts.inconsolata
      iosevka
      fira-code
      # nerdfonts
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
    # include libstdc++ in the nix-ld profile
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

  # programs.ydotool.enable = true;

  # services.ollama = {
  #   enable = per_machine_vars.enable_nvidia;
  #   package = pkgs.ollama-cuda;
  #   acceleration = "cuda";
  # };

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

    inputs.wezterm-flake.packages.${pkgs.system}.default
    # inputs.lem.packages.${pkgs.system}.lem-ncurses
    inputs.lem.packages.${pkgs.system}.lem-sdl2

    # text editors
    # vscode

    # media tools
    mpv
    vlc
    feh # i use it to set wallpaper
    my_sxiv
    telegram-desktop
    youtube-music
    okular zathura foliate mupdf
    xournalpp # rnote krita
    # krita
    # lollypop clementine
    ocrmypdf pdftk pdfgrep poppler_utils djvu2pdf fntsample #calibre
    djvulibre
    # qimgv
    jellyfin jellyfin-web jellyfin-ffmpeg jellyfin-media-player jellycli jellyfin-mpv-shim
    imv

    # media manipulation tools
    inkscape # gimp

    # general tools
    # google-chrome nyxt tor-browser-bundle-bin # qutebrowser
    brave tor-browser-bundle-bin google-chrome
    scrcpy
    pavucontrol
    libreoffice
    neovide

    # commandline tools
    # wezterm kitty
    pulsemixer # tui for pulseaudio control
    alsa-utils
    playerctl # media control
    gptfdisk parted
    libtool # to compile vterm
    xdotool
    btrfs-progs
    sshpass

    # x11 tools
    # rofi
    libnotify
    # xclip xsel
    # maim # maim is a better alternative to scrot
    # hsetroot
    # unclutter
    # xorg.xev
    # sxhkd
    # xorg.xwininfo
    # xorg.xauth

    # wayland
    # gnomeExtensions.xremap
    wl-clipboard
    waybar
    grim slurp # for screenshots
    wofi
    eww
    brightnessctl
    swww
    wf-recorder
    hyprpicker
    iio-hyprland
    swappy # for quick snapshot image editing
    wvkbd # onboard alternative (on-screen keyboard)
    zenity
    squeekboard
    flameshot
    wl-screenrec

    vdhcoapp # for firefox video download helper

    # other
    zoom-us #, do i realy want this running natively?
    hugo
    adb-sync
    # woeusb-ng
    ntfs3g
    gnupg
    SDL2
    sass
    simplescreenrecorder
    usbutils
    pciutils
    subversion # git alternative
    # logseq
    graphviz
    # firebase-tools
    # graphqlmap
    isync
    notmuch
    # nuclear
    # python312Packages.google
    # popcorntime
    stremio
    syncthing
    monolith # save webpages
    wallabag

    # soulseek?
    # soulseekqt
    # nicotine-plus

    # for listening to radio music?
    # strawberry
    # shortwave

    # scientific computation?
    gnuplot
    lean
    # sentencepiece
    # sageWithDoc sagetex
    kaggle google-cloud-sdk python3Packages.huggingface-hub python3Packages.datasets

    # quickly start VMs
    quickemu

    # some programming languages/environments
    (lua.withPackages(ps: with ps; [ busted luafilesystem luarocks ]))
    # flutter dart android-studio android-tools genymotion
    texlive.combined.scheme-full
    rustc meson ninja
    # jupyter
    typescript
    # desktop_vars.desktop_julia
    # julia-bin
    # julia
    python3Packages.west
    typst
    tailwindcss
    poetry
    # desktop_vars.desktop_python
    #python3
    neo4j
    bun

    # lisps
    babashka
    chicken
    guile
    racket
    # common lisp
    (sbcl.withPackages (ps: with ps; [
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
    ]))
    # usage example:
    # $ sbcl
    # * (load (sb-ext:posix-getenv "ASDF"))
    # * (asdf:load-system 'alexandria)

    # offline docs
    # zeal devdocs-desktop

    # some helpful programs / other
    onboard # onscreen keyboard
    xcape keyd # haskellPackages.kmonad  # keyboard utilities
    pulseaudioFull
    prettierd # for emacs apheleia
    nodePackages.prettier # for emacs apheleia
    # ruff # python code formatter
    black

    # lsp
    haskell-language-server emmet-language-server clojure-lsp #llm-ls
    nodePackages.node2nix yaml-language-server postgres-lsp ansible-language-server
    asm-lsp htmx-lsp cmake-language-server lua-language-server java-language-server # typst-lsp
    tailwindcss-language-server
    nodePackages.bash-language-server
    nil
    texlab
    sqls
    ruff-lsp
    python3Packages.python-lsp-server
    nodePackages_latest.typescript-language-server
    vscode-langservers-extracted

    # dictionary
    (aspellWithDicts (dicts: with dicts; [ en en-computers en-science ]))
    # enchant.dev # for emacs jinx-mode

    liquidctl
    libinput

    bluez-tools blueman

    # image viewer
    vimiv-qt

    # for widgets
    (pkgs.python3Packages.buildPythonPackage rec {
      pname = "widgets";
      format = "other";
      version = "1.0";
      dontBuild = true;
      dontUnpack = true;

      src = /home/mahmooz/work/widgets;

      nativeBuildInputs = with pkgs; [ gobject-introspection ];
      buildInputs = with pkgs; [ gtk3 gtk-layer-shell wrapGAppsHook ];
      # propagatedBuildInputs = with python3Packages; [ pygobject3 pydbus ];
      propagatedBuildInputs = with python3Packages; [
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
    koboldcpp jan cudatoolkit nvtopPackages.full
    llama-cpp
  ]);

  # services.prometheus = {
  #   enable = true;
  #   port = 9001;
  # };
  # services.monit.enable = true;

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

  systemd.services.my_llama_cpp_service = {
    enable = per_machine_vars.enable_nvidia;
    description = "llama";
    wantedBy = [ "multi-user.target" ];
    script = "${pkgs.llama-cpp}/bin/llama-server --host 0.0.0.0 --port 8080 -m /home/mahmooz/models/DeepSeek-R1-Distill-Qwen-14B-Q8_0.gguf --host 0.0.0.0 --cache-type-k q8_0 --n-gpu-layers 20 --threads 16"; # -k q8_0 may be very important, https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF
    serviceConfig = {
      User = "mahmooz";
      # Restart = "always";
    };
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

  # systemd.services.my_syncthing = {
  #   description = "mpv logger";
  #   wantedBy = [ "multi-user.target" ];
  #   script = "${pkgs.syncthing}/bin/syncthing --home=/home/mahmooz/.syncthing_config";
  #   serviceConfig = {
  #     User = "mahmooz";
  #   };
  # };

  # make electron apps work properly with wayland?
  # environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # without this okular is blurry
  environment.sessionVariables.QT_QPA_PLATFORM = "wayland";

  qt = {
    enable = true;
    platformTheme = "qt5ct";
    style = "adwaita-dark";
  };

  # note that you may have to ssh first manually for the main server to be inserted into known_hosts file so that this would work
  # systemd.services.my_ssh_tunnel_service = {
  #   description = "ssh tunnel";
  #   after = [ "network.target" "network-online.target" ];
  #   wants = [ "network-online.target" ];
  #   script = "[ -f ${server_vars.main_key} ] && ${pkgs.openssh}/bin/ssh -i ${server_vars.main_key} -R '*:${toString per_machine_vars.remote_tunnel_port}:*:22' ${server_vars.main_server_user}@${server_vars.main_server_ip} -NTg -o ServerAliveInterval=60";
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     User = "mahmooz";
  #     Type = "simple";
  #     Restart = "on-failure";
  #     RestartSec = "5s";
  #     RuntimeMaxSec = "3600";
  #     # Restart = "always";
  #   };
  # };

  services.udev.extraRules = ''
    SUBSYSTEM=="block", ENV{ID_FS_UUID}=="777ddbd7-9692-45fb-977e-0d6678a4a213", RUN+="${pkgs.coreutils}/bin/mkdir -p /home/mahmooz/mnt" RUN+="${pkgs.systemd}/bin/systemd-mount $env{DEVNAME} /home/mahmooz/mnt/", RUN+="${lib.getExe pkgs.logger} --tag my-manual-usb-mount udev rule success, drive: %k with uuid $env{ID_FS_UUID}"
    SUBSYSTEM=="block", ENV{ID_FS_UUID}=="be5af23f-da6d-42ee-a346-5ad3af1a299a", RUN+="${pkgs.coreutils}/bin/mkdir -p /home/mahmooz/mnt2" RUN+="${pkgs.systemd}/bin/systemd-mount $env{DEVNAME} /home/mahmooz/mnt2", RUN+="${lib.getExe pkgs.logger} --tag my-manual-usb-mount udev rule success, drive: %k with uuid $env{ID_FS_UUID}"
  '';
}