{ config, pkgs, lib, inputs, pinned-pkgs, ... }:

let
  server_vars = (import ./server_vars.nix { inherit pkgs pinned-pkgs config; });
  constants = (import ./constants.nix);
  desktop_vars = (import ./desktop_vars.nix { inherit pkgs pinned-pkgs config; });
  mypython = desktop_vars.desktop_python;
in
{
  imports = [
    # ./sillytavern.nix
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

    # for firmware updates
    services.fwupd.enable = true;

    # automatic screen rotation?
    hardware.sensor.iio.enable = true;

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
    hardware.nvidia.open = false;
    hardware.nvidia-container-toolkit.enable = config.machine.enable_nvidia;

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


    # will this help prevent the dbus org.freedesktop.secrets error when using goose-cli?
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.sddm.enableGnomeKeyring = true;

    # my overlays
    nixpkgs.overlays = [
      # enable pgtk so its not pixelated on wayland
      (self: super: {
        my_emacs = (super.emacs.override { withImageMagick = true; withXwidgets = false; withPgtk = true; withNativeCompilation = true; withCompressInstall = false; withTreeSitter = true; withGTK3 = true; withX = false; }).overrideAttrs (oldAttrs: rec {
          imagemagick = pkgs.imagemagickBig;
        });
      })

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
    # virtualisation.docker.enable = true;
    # virtualisation.docker.enableNvidia = config.machine.enable_nvidia;
    virtualisation.podman = {
      enableNvidia = config.machine.enable_nvidia;
      dockerCompat = true;  # optional, adds `docker` alias
      enable = true;
      autoPrune.enable = true;
      defaultNetwork.settings = { dns_enabled = true; };
      extraPackages = [
        pkgs.curl
      ];
    };
    # virtualisation.docker.rootless = {
    #   enable = true;
    #   setSocketVariable = true;
    # };

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
      code-cursor
      neovide
      windsurf

      ((emacsPackagesFor my_emacs).emacsWithPackages(epkgs: with epkgs; [
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
      darktable # image editor
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
      zeal dasht
      material-design-icons

      # some programming languages/environments
      (texlive.combined.scheme-full.withPackages((ps: with ps; [ pinned-pkgs.sagetex ])))
      # desktop_vars.desktop_julia
      # julia
      typst
      pinned-pkgs.sageWithDoc

      # lsp
      cmake-language-server
      nodePackages.bash-language-server
      nil
      python3Packages.python-lsp-server
      vscode-langservers-extracted

      # dictionary
      (aspellWithDicts (dicts: with dicts; [ en en-computers en-science ]))

      # text-generation-inference
      inputs.tgi.packages.${pkgs.system}.default
      inputs.tgi.packages.${pkgs.system}.server

      # for widgets
      # we need to "purify" this..
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

      llama-cpp koboldcpp
      aichat shell-gpt
      # local-ai # nvidia build failure
      # private-gpt build failure
      # https://github.com/natsukium/mcp-servers-nix/blob/main/pkgs/default.nix
      mcp-server-fetch
      mcp-server-everything
      mcp-server-time
      mcp-server-git
      mcp-server-sequential-thinking
      mcp-server-filesystem
      mcp-server-redis
      playwright-mcp
      mcp-server-github github-mcp-server
      mcp-server-memory
      mcp-server-brave-search
      mcp-server-sqlite
      # gpt4all librechat
    ] ++ pkgs.lib.optionals config.machine.enable_nvidia [
      cudatoolkit nvtopPackages.full
    ] ++ server_vars.server_packages;

    systemd.services.my_mpv_logger_service = {
      description = "mpv logger";
      wantedBy = [ "multi-user.target" ];
      script = "${pkgs.dash}/bin/dash ${constants.scripts_dir}/mpv_logger.sh";
      serviceConfig = {
        User = "mahmooz";
        Restart = "always";
        RuntimeMaxSec = "3600";
        # ExecStart = "${pkgs.coreutils}/bin/sh ${constants.scripts_dir}/mpv_logger.sh";
      };
    };

    services.open-webui = {
      package = pkgs.open-webui;
      enable = false;
      port = 8083;
      environment = {
        WEBUI_AUTH = "False";
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
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

    # without this okular is blurry
    environment.sessionVariables.QT_QPA_PLATFORM = "wayland";

    # run vllm through docker (its broken in nixpkgs, but this may be better anyway?)
    virtualisation.oci-containers = {
      backend = "podman";
      containers = {
        vllm = {
          autoStart = false;
          image = "vllm/vllm-openai:latest";
          ports = [ "5000:5000" ];
          extraOptions = [
            "--runtime" "nvidia"
            "--gpus" "all"
            "--ipc" "host"
            "--pull=always"
            "--network=host"
          ];
          cmd = [
            "--model" "mistralai/Mistral-7B-v0.1"
          ];
        };
      };
    };

    services.udev.extraRules = ''
    SUBSYSTEM=="block", ENV{ID_FS_UUID}=="777ddbd7-9692-45fb-977e-0d6678a4a213", RUN+="${pkgs.coreutils}/bin/mkdir -p /home/mahmooz/mnt" RUN+="${pkgs.systemd}/bin/systemd-mount $env{DEVNAME} /home/mahmooz/mnt/", RUN+="${lib.getExe pkgs.logger} --tag my-manual-usb-mount udev rule success, drive: %k with uuid $env{ID_FS_UUID}"
    SUBSYSTEM=="block", ENV{ID_FS_UUID}=="be5af23f-da6d-42ee-a346-5ad3af1a299a", RUN+="${pkgs.coreutils}/bin/mkdir -p /home/mahmooz/mnt2" RUN+="${pkgs.systemd}/bin/systemd-mount $env{DEVNAME} /home/mahmooz/mnt2", RUN+="${lib.getExe pkgs.logger} --tag my-manual-usb-mount udev rule success, drive: %k with uuid $env{ID_FS_UUID}"
  '';
  };
}