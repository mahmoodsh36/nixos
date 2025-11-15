{ config, pkgs, lib, inputs, pkgs-master, myutils, ... }:

let
  constants = (import ../lib/constants.nix);
  work_dir = "${config.machine.voldir}/work";
  scripts_dir = "${config.machine.voldir}/work/scripts";
  keys_python = pkgs.python3.withPackages (ps: with ps; [ evdev ]);
  gtk_python_env = (pkgs.python3.withPackages (ps: with ps; [
    pygobject3
    pydbus
  ]));
  gtkpython = pkgs.stdenv.mkDerivation rec {
    pname = "gtkpython";
    version = "1.0";

    nativeBuildInputs = [
      pkgs.gobject-introspection
      pkgs.wrapGAppsHook3
    ];

    buildInputs = with pkgs; [
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
  emacs_base_pkg = inputs.emacs.packages.${pkgs.system}.emacs-git;
  emacs_pkg = (emacs_base_pkg.override {
    withImageMagick = false;
    withXwidgets = false;
    withPgtk = true;
    withNativeCompilation = true;
    withCompressInstall = false;
    withTreeSitter = true;
    withGTK3 = true;
    withX = false;
  }).overrideAttrs (oldAttrs: rec {
    imagemagick = pkgs.imagemagickBig;
  });
in
{
  config = lib.mkIf (config.machine.is_linux && config.machine.is_desktop) {
    boot = {
      kernelParams = [
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "usbcore.autosuspend=-1" # or 120 to wait two minutes, etc
      ];
    } // lib.mkIf (config.machine.name == "mahmooz2") {
      # im using this adapter on mahmooz2 only. no need to use this kernel
      # on mahmooz1 (or other devices)
      kernelPackages = pkgs.linuxPackages_6_6;
      extraModulePackages = [
        (config.boot.kernelPackages.callPackage ../packages/rtl8188gu.nix {})
      ];
    };

    # better safe than sorry (for having to deal with firmware/driver issues)..?
    hardware.enableAllHardware = true;
    hardware.enableAllFirmware = true;
    hardware.usb-modeswitch.enable = true;
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

    # graphical stuff (wayland,x11,etc)
    services.xserver = {
      enable = true;
      xkb.layout = "us,il,ara";
      desktopManager.xfce.enable = (!constants.enable_plasma);
    };
    services.desktopManager.gnome.enable = true;
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
      # package = pkgs.hyprland;
      package = (myutils.packageFromCommit {
        rev = "ab0f3607a6c7486ea22229b92ed2d355f1482ee0";
        packageName = "hyprland";
      });
      xwayland.enable = true;
    };
    xdg.portal = {
      # xdgOpenUsePortal = true; # this seems to override my .desktop definitions in home-manager?
      enable = true;
      extraPortals = [
        # pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
        # pkgs.xdg-desktop-portal-hyprland
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
        user = "${config.machine.user}";
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
    programs.adb.enable = true;

    # hybrid sleep when press power button. doesnt work anymore
    # services.logind.extraConfig = ''
    #   HandlePowerKey=ignore
    #   IdleAction=ignore
    #   IdleActionSec=1m
    # '';
    # dont hibernate when lid is closed
    services.logind.lidSwitch = "ignore";

    # spice-gtk?
    programs.virt-manager.enable = true;
    users.groups.libvirtd.members = [ config.machine.user ];
    virtualisation.spiceUSBRedirection.enable = true;

    # dictionaries
    services.dictd.enable = true;
    services.dictd.DBs = with pkgs.dictdDBs; [ wiktionary wordnet ];
    environment.wordlist.enable = true;

    documentation.dev.enable = true;

    # needed for uvx too
    programs.nix-ld = {
      enable = true;
      libraries = [
        # pkgs.python3Packages.torch.lib
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
        pkgs.pkg-config
        # pkgs.glibc_multi
        # pkgs.glib
        # pkgs.glibc
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

    environment.systemPackages = with pkgs; [
      gtkpython

      # overwrite notify-send to not let anything handle notifications
      (pkgs.writeShellScriptBin "notify-send" ''
        echo $@ > /tmp/notif
      '')

      inputs.lem.packages.${pkgs.system}.lem-webview
      neovide
      # code-cursor windsurf
      # inputs.wezterm.packages.${pkgs.system}.default

      ((emacsPackagesFor emacs_pkg).emacsWithPackages(epkgs: with epkgs; [
        treesit-grammars.with-all-grammars
      ]))

      # media tools
      # feh # image viewer (can it set wallpaper on wayland?)
      kdePackages.okular zathura foliate mupdf
      xournalpp # rnote krita
      ocrmypdf pdftk pdfgrep poppler-utils
      imv # nice image viewer
      spotube # open source spotify client?
      inkscape
      nyxt
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
      darktable # image editor
      # digikam # another image viewer?
      swww # wallpaper setter

      simplescreenrecorder
      usbutils
      pciutils
      liquidctl
      libinput
      bluez-tools blueman
      pulseaudioFull
      spice-gtk # used with quickemu
      # zeal dasht # code docs?
      material-design-icons
      virt-viewer
      openrgb-with-all-plugins
      # tor-browser

      vdhcoapp # for firefox video download helper
      woeusb-ng
      quickemu # quickly start VMs
      ventoy
      acpi lm_sensors
      cryptsetup
      # jellyfin-tui jellycli jellytui

      steam-run-free
    ];

    systemd.services.my_mpv_logger_service = {
      description = "mpv logger";
      wantedBy = [ "multi-user.target" ];
      script = "${pkgs.dash}/bin/dash ${scripts_dir}/mpv_logger.sh";
      serviceConfig = {
        User = config.machine.user;
        Restart = "always";
        RuntimeMaxSec = "3600";
      };
    };

    systemd.services.my_keys_py_service = {
      description = "service for keys.py";
      wantedBy = [ "multi-user.target" ];
      # choose glove80 if its present
      script = ''
        export kbd=$(${pkgs.libinput}/bin/libinput list-devices | ${pkgs.gnugrep}/bin/grep glove80 -i -A 10 | ${pkgs.gnugrep}/bin/grep Kernel: | ${pkgs.gawk}/bin/awk '{print $2}'); [ -z "$kbd" ] && ${pkgs.dash}/bin/dash -lc '${keys_python}/bin/python ${work_dir}/keys/keys.py -d' || ${pkgs.dash}/bin/dash -lc "${keys_python}/bin/python ${work_dir}/keys/keys.py -d -p $kbd"
      '';
      serviceConfig = {
        Restart = "always";
      };
      unitConfig = {
        ConditionPathExists = "${work_dir}/keys/keys.py";
      };
    };

    # without this okular is blurry
    environment.sessionVariables.QT_QPA_PLATFORM = "wayland";

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

    services.guix.enable = true;

    powerManagement = {
      enable = true;
      powertop.enable = true;
      cpuFreqGovernor = "ondemand";
    };

    # ccache is needed for robotnix
    nix.settings.extra-sandbox-paths = [ config.programs.ccache.cacheDir ];
    programs.ccache.enable = true;

    # helps finding the package that contains a specific file
    programs.nix-index = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
    };
    programs.command-not-found.enable = false; # needed for nix-index

    programs.dconf.enable = true;
  };
}