{ config, pkgs, lib, inputs, pkgs-pinned, ... }:

let
  server_vars = (import ./server_vars.nix { inherit pkgs pkgs-pinned config inputs; });
  constants = (import ./constants.nix);
  desktop_vars = (import ./desktop_vars.nix { inherit pkgs pkgs-pinned config inputs; });
  main_python = desktop_vars.desktop_python;
  # main_julia = desktop_vars.desktop_julia;
  main_julia = pkgs.julia;
  keys_python = pkgs-pinned.python3.withPackages (ps: with ps; [ evdev ]);
  emacs_pkg = (pkgs-pinned.emacs.override { withImageMagick = false; withXwidgets = false; withPgtk = true; withNativeCompilation = true; withCompressInstall = false; withTreeSitter = true; withGTK3 = true; withX = false; }).overrideAttrs (oldAttrs: rec {
    imagemagick = pkgs.imagemagickBig;
  });
  gtk_python_env = (pkgs-pinned.python3.withPackages (ps: with ps; [
    pygobject3
    pydbus
  ]));
  packageFromCommit = { rev, packageName }:
    let
      src-url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
      nixpkgs-src = builtins.fetchTarball {
        url = src-url;
      };
      pkgs-at-commit = import nixpkgs-src {
        system = builtins.currentSystem;
        config = {
          cudaSupport = config.machine.enable_nvidia;
          allowUnfree = true;
        };
      };
    in
      pkgs-at-commit."${packageName}";
  gtkpython = pkgs-pinned.stdenv.mkDerivation rec {
    pname = "gtkpython";
    version = "1.0";

    nativeBuildInputs = [
      pkgs-pinned.gobject-introspection
      pkgs-pinned.wrapGAppsHook
    ];

    buildInputs = with pkgs-pinned; [
      gtk_python_env
      gtk3
    ];

    dontUnpack = true;

    installPhase = ''
      mkdir -p $out/bin
      cp ${gtk_python_env}/bin/python $out/bin/gtkpython
      chmod +x $out/bin/gtkpython
    '';
  };
in
{
  imports = [
  ];

  config = lib.mkIf config.machine.is_desktop {
    boot.kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "usbcore.autosuspend=-1" # or 120 to wait two minutes, etc
    ];

    # better safe than sorry (for having to deal with firmware/driver issues)..?
    hardware.enableAllHardware = true;
    hardware.enableAllFirmware = true;

    services.hardware.bolt.enable = true;

    # for firmware updates
    services.fwupd.enable = true;

    # automatic screen rotation?
    hardware.sensor.iio.enable = true;

    # openrgb for controlling rgb lighting
    services.hardware.openrgb.enable = true;
    hardware.i2c.enable = true;

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
    security.rtkit.enable = true; # realtime audio support, do i need this?
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
      # the patch now messes things up
  #     (final: prev: {
  #       yt-dlp = prev.yt-dlp.overrideAttrs (old: {
  #         nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.perl ];

  #         # src = pkgs.fetchFromGitHub {
  #         #   owner = "yt-dlp";
  #         #   repo = "yt-dlp";
  #         #   rev = "73bf10211668e4a59ccafd790e06ee82d9fea9ea";
  #         #   sha256 = "07kkrmbld6jsknyyf3b171njdmh73xfjf86k6fl5zd30bma1fbiw";
  #         # };

  #         # to remove the blocked urls
  #         patchPhase = ''
  #   ${old.patchPhase or ""}
  #   perl -0777 -i -pe 's/^[ \t]*URLS = \((?!\))(.|\n)*?^[ \t]*\)/    URLS = ()\n/msg' yt_dlp/extractor/unsupported.py
  #   perl -0777 -i -pe 's/^([ \t]*)_TESTS = \[\{(?:.|\n)*?\}\][ \t]*\n/''${1}_TESTS = []\n/msg' yt_dlp/extractor/unsupported.py
  # '';
  #       });
  #     })

      inputs.mcp-servers-nix.overlays.default
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
        additionalOptions = ''
          Option "PalmDetection" "on"
        '';
      };
    };
    programs.hyprland = {
      enable = true;
      package = pkgs.hyprland;
      xwayland.enable = true;
    };
    xdg.portal = {
      # xdgOpenUsePortal = true; # this seems to override my .desktop definitions in home-manager?
      enable = true;
      extraPortals = [
        # pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-hyprland
        (lib.mkIf constants.enable_plasma pkgs.kdePackages.xdg-desktop-portal-kde)
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
      sddm = {
        enable = true;
        wayland.enable = true;
        enableHidpi = true;
        settings.General.DisplayServer = "wayland";
      };
      defaultSession = "hyprland";
      # defaultSession = "gnome";
      # defaultSession = "plasma";
    };
    services.desktopManager.plasma6.enable = constants.enable_plasma;
    environment.etc."xdg/baloofilerc".source = lib.mkIf constants.enable_plasma (
      (pkgs.formats.ini {}).generate "baloorc" {
        "Basic Settings" = {
          "Indexing-Enabled" = false;
        };
      }
    );
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      spectacle # to avoid building opencv
    ];

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

    # spice-gtk?
    programs.virt-manager.enable = true;
    users.groups.libvirtd.members = [ constants.myuser ];
    virtualisation.spiceUSBRedirection.enable = true;

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

    # helps finding the package that contains a specific file
    programs.nix-index = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
    };
    programs.command-not-found.enable = false; # needed for nix-index

    # needed for uvx too
    programs.nix-ld = {
      enable = true;
      libraries = [
        pkgs.python3Packages.torch.lib
        pkgs.stdenv.cc.cc
        pkgs.zlib
        pkgs.fuse3
        pkgs.icu
        pkgs.nss
        pkgs.openssl
        pkgs.curl
        pkgs.expat
        pkgs.xorg.libX11
        pkgs.libGL
        pkgs.stdenv.cc.cc.lib
        pkgs.glib
        pkgs.ncurses5
        pkgs.libzip
        pkgs.cmake
        pkgs.llvm_18
        pkgs.zstd
        pkgs.attr
        pkgs.libssh
        pkgs.bzip2
        pkgs.libaio
        pkgs.file
        pkgs.libxml2
        pkgs.acl
        pkgs.libsodium
        pkgs.util-linux
        pkgs.binutils
        pkgs.xz
        pkgs.systemd
        pkgs.glibc_multi
        pkgs.pkg-config
        pkgs.glibc
        pkgs.pythonManylinuxPackages.manylinux2014Package
      ] ++ pkgs.lib.optionals config.machine.enable_nvidia [
        pkgs.linuxPackages.nvidia_x11
        pkgs.cudaPackages.cudatoolkit
        pkgs.cudaPackages.cudnn
        pkgs.cudaPackages.cuda_cudart
        pkgs.cudaPackages.cuda_cudart.static
        pkgs.cudaPackages.cuda_cccl
        pkgs.cudaPackages.cuda_cupti
        pkgs.cudaPackages.cuda_nvcc
        pkgs.cudaPackages.cuda_nvml_dev
        pkgs.cudaPackages.cuda_nvrtc
        pkgs.cudaPackages.cuda_nvtx
        pkgs.cudaPackages.cutensor
        pkgs.cudaPackages.libcublas
        pkgs.cudaPackages.libcufft
        pkgs.cudaPackages.libcurand
        pkgs.cudaPackages.libcusolver
        pkgs.cudaPackages.libcusparse
        pkgs.cudaPackages.cusparselt
        pkgs.cudaPackages.libcufile
        pkgs.cudaPackages.nccl
      ];
    };

    # packages
    environment.systemPackages = with pkgs; [
      (pkgs.writeShellScriptBin "python" ''
        # may not need LD_* here
        # export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
        exec ${main_python}/bin/python "$@"
      '')
      (pkgs.writeShellScriptBin "python3" ''
        exec ${main_python}/bin/python "$@"
      '')
      (pkgs.writeShellScriptBin "ipython" ''
        exec ${main_python}/bin/ipython --no-confirm-exit "$@"
      '')

      gtkpython

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
        exec ${main_julia}/bin/julia "$@"
      '')

      inputs.lem.packages.${pkgs.system}.lem-sdl2
      code-cursor
      neovide
      windsurf

      ((emacsPackagesFor emacs_pkg).emacsWithPackages(epkgs: with epkgs; [
        treesit-grammars.with-all-grammars
      ]))

      # media tools
      mpv
      # feh # image viewer (can it set wallpaper on wayland?)
      kdePackages.okular zathura foliate mupdf
      xournalpp # rnote krita
      ocrmypdf pdftk pdfgrep poppler_utils
      imv # nice image viewer
      spotube # open source spotify client?
      inkscape
      # nyxt
      youtube-music
      telegram-desktop

      scrcpy
      pavucontrol
      libreoffice
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
      # darktable # image editor
      # digikam # another image viewer?
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
      quickemu # quickly start VMs
      spice-gtk # used with quickemu
      zeal dasht # code docs?
      material-design-icons
      # ventoy
      djvulibre djvu2pdf
      czkawka czkawka-full # file dupe finder/cleaner? has a gui too
      # python3Packages.chromadb # vector database
      nodePackages.prettier
      nodejs pnpm
      exiftool
      spotdl
      openjdk
      transmission_4 acpi lm_sensors
      you-get aria ytdl-sub yt-dlp
      playwright
      uv
      argc
      cryptsetup
      imagemagickBig ghostscript # ghostscript is needed for some imagemagick commands
      ffmpeg-full.bin # untrunc-anthwlock
      pandoc
      pigz # for compression
      virt-viewer
      openrgb-with-all-plugins
      tor-browser
      jellyfin-tui jellycli jellytui
      kando

      # nix specific
      nixos-generators
      nix-prefetch-git
      nix-tree
      nixos-anywhere
      nix-init
      steam-run-free

      # some programming languages/environments
      # julia
      (texlive.combined.scheme-full.withPackages((ps: with ps; [ pkgs-pinned.sagetex ])))
      typst
      (lib.mkIf (!config.machine.enable_nvidia) pkgs-pinned.sageWithDoc) # to avoid building

      # lsp
      cmake-language-server
      nodePackages.bash-language-server
      nil
      python3Packages.python-lsp-server
      vscode-langservers-extracted

      # dictionary
      (aspellWithDicts (dicts: with dicts; [ en en-computers en-science ]))

      python3Packages.huggingface-hub
      # aider-chat
      # goose-cli # goose ai tool
      gemini-cli

      # koboldcpp mistral-rs
      config.machine.llama-cpp.pkg
      (whisper-cpp.overrideAttrs (old: {
        src = pkgs.fetchFromGitHub {
          owner = "ggml-org";
          repo = "whisper.cpp";
          rev = "c85b1ae84eecbf797f77a76a30e648c5054ee663";
          sha256 = "sha256-ABgsfkT7ghOGe2KvcnyP98J7mDI18BWtJGb1WheAduE=";
        };
      }))
      # vllm
      aichat
      opencode

      # private-gpt jan llm
      # fabric-ai ragflow dify

      # https://github.com/natsukium/mcp-servers-nix/blob/main/pkgs/default.nix
      mcp-server-everything
      mcp-server-time
      mcp-server-git
      mcp-server-sequential-thinking
      mcp-server-filesystem
      playwright-mcp
      mcp-server-github github-mcp-server
      mcp-server-sqlite

      (packageFromCommit {
        rev = "f06333d605155b2b8abdba95892a2e6b31ea16b9";
        packageName = "mistral-rs";
      })

      gitingest
    ] ++ pkgs.lib.optionals config.machine.enable_nvidia [
      cudatoolkit nvtopPackages.full
    ] ++ server_vars.server_packages;

    # vector database for RAG
    services.qdrant = {
      enable = config.machine.is_desktop;
      settings.service.host = "0.0.0.0";
    };

    systemd.services.my_mpv_logger_service = {
      description = "mpv logger";
      wantedBy = [ "multi-user.target" ];
      script = "${pkgs.dash}/bin/dash ${constants.scripts_dir}/mpv_logger.sh";
      serviceConfig = {
        User = constants.myuser;
        Restart = "always";
        RuntimeMaxSec = "3600";
      };
    };

    systemd.services.my_keys_py_service = {
      description = "service for keys.py";
      wantedBy = [ "multi-user.target" ];
      # choose glove80 if its present
      script = ''
        export kbd=$(${pkgs.libinput}/bin/libinput list-devices | ${pkgs.gnugrep}/bin/grep glove80 -i -A 10 | ${pkgs.gnugrep}/bin/grep Kernel: | ${pkgs.gawk}/bin/awk '{print $2}'); [ -z "$kbd" ] && ${pkgs.dash}/bin/dash -lc '${keys_python}/bin/python ${constants.work_dir}/keys/keys.py -d' || ${pkgs.dash}/bin/dash -lc "${keys_python}/bin/python ${constants.work_dir}/keys/keys.py -d -p $kbd"
      '';
      serviceConfig = {
        Restart = "always";
      };
      unitConfig = {
        ConditionPathExists = "${constants.work_dir}/keys/keys.py";
      };
    };

    # without this okular is blurry
    environment.sessionVariables.QT_QPA_PLATFORM = "wayland";

    # http://localhost:28981
    environment.etc."paperless-admin-pass".text = "admin";
    services.paperless = {
      # enable = true;
      passwordFile = "/etc/paperless-admin-pass";
    };

    # make disablewhiletyping and other settings work with keys.py (libevdev-based key remapper, https://github.com/rvaiya/keyd/issues/66#issuecomment-985983524)
    environment.etc."libinput/local-overrides.quirks".text = pkgs.lib.mkForce ''
      [Serial Keyboards]
      MatchUdevType=keyboard
      MatchName=virtual*
      AttrKeyboardIntegration=internal
    '';

    services.udev.extraRules = ''
      SUBSYSTEM=="block", ENV{ID_FS_UUID}=="777ddbd7-9692-45fb-977e-0d6678a4a213", RUN+="${pkgs.coreutils}/bin/mkdir -p /home/mahmooz/mnt" RUN+="${pkgs.systemd}/bin/systemd-mount $env{DEVNAME} /home/mahmooz/mnt/", RUN+="${lib.getExe pkgs.logger} --tag my-manual-usb-mount udev rule success, drive: %k with uuid $env{ID_FS_UUID}"
      SUBSYSTEM=="block", ENV{ID_FS_UUID}=="be5af23f-da6d-42ee-a346-5ad3af1a299a", RUN+="${pkgs.coreutils}/bin/mkdir -p /home/mahmooz/mnt2" RUN+="${pkgs.systemd}/bin/systemd-mount $env{DEVNAME} /home/mahmooz/mnt2", RUN+="${lib.getExe pkgs.logger} --tag my-manual-usb-mount udev rule success, drive: %k with uuid $env{ID_FS_UUID}"
  '';

    # services.guix.enable = true;
    programs.adb.enable = true;
    programs.java.enable = true;
    programs.sniffnet.enable = true;
    programs.wireshark.enable = true;
    programs.dconf.enable = true;

    services.mysql = {
      enable = false;
      settings.mysqld.bind-address = "0.0.0.0";
      package = pkgs.mariadb;
    };

    services.mongodb = {
      enable = true;
      bind_ip = "0.0.0.0";
    };

    services.postgresql = {
      enable = false;
      enableTCPIP = true;
      authentication = pkgs.lib.mkOverride 10 ''
      # generated file; do not edit!
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            trust
      host    all             all             ::1/128                 trust
      '';
      # package = pkgs.postgresql_16;
      ensureDatabases = [ "mahmooz" ];
      # port = 5432;
      initialScript = pkgs.writeText "backend-initScript" ''
        CREATE ROLE mahmooz WITH LOGIN PASSWORD 'mahmooz' CREATEDB;
        CREATE DATABASE test;
        GRANT ALL PRIVILEGES ON DATABASE test TO mahmooz;
      '';
      ensureUsers = [{
        name = "mahmooz";
        ensureDBOwnership = true;
      }];
    };

    powerManagement = {
      enable = true;
      powertop.enable = true;
      cpuFreqGovernor = "ondemand";
    };

    services.open-webui = lib.mkIf (lib.and config.machine.is_desktop (!config.machine.enable_nvidia)) {
      enable = false;
      host = "0.0.0.0";
      port = 8083;
      environment = {
        WEBUI_AUTH = "False";
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
      };
    };
  };
}