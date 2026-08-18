{ config, pkgs, lib, inputs, myutils, pkgs-pinned, ... }:

let
  constants = (import ../lib/constants.nix);
  gnome_enabled = constants.enable_gnome && !config.machine.low_resources;
  work_dir = "${config.machine.voldir}/work";
  scripts_dir = "${config.machine.voldir}/work/scripts";
  gtk_python_env = (pkgs.python3.withPackages (ps: with ps; [
    pygobject3
    pydbus
  ]));
  # xremap's .launch forks children directly, so they inherit its unit's
  # RestrictAddressFamilies=AF_UNIX seccomp filter and get no network.
  # --user makes the user manager fork instead; --scope would not, it
  # forks from the caller and keeps the filter.
  spawn = pkgs.writeShellScriptBin "spawn" ''
    cmd=$(command -v "$1") || { echo "spawn: $1 not found" >&2; exit 127; }
    shift
    exec ${pkgs.systemd}/bin/systemd-run --user --collect --quiet \
      --unit="spawn-$(basename "$cmd")-$$" --setenv=PATH="$PATH" \
      -- "$cmd" "$@"
  '';

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
 in
{
  imports = [ inputs.xremap-flake.nixosModules.default ];

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
    hardware.enableAllHardware = (!config.machine.is_vm) && (!config.machine.low_resources);
    hardware.enableAllFirmware = (!config.machine.is_vm) && (!config.machine.low_resources);
    hardware.usb-modeswitch.enable = !config.machine.low_resources;
    services.hardware.bolt.enable = !config.machine.low_resources;

    # for firmware updates
    services.fwupd.enable = (!config.machine.is_vm) && (!config.machine.low_resources);

    # automatic screen rotation?
    hardware.sensor.iio.enable = (!config.machine.is_vm) && (!config.machine.low_resources);

    # openrgb for controlling rgb lighting
    services.hardware.openrgb.enable = (!config.machine.is_vm) && (!config.machine.low_resources);
    hardware.i2c.enable = !config.machine.low_resources;

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
    # services.xserver = {
    #   enable = true;
    #   xkb.layout = "us,il,ara";
    #   desktopManager.xfce.enable = (!constants.enable_plasma);
    # };
    services.desktopManager.gnome.enable = gnome_enabled;
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
      xwayland.enable = true;
      # systemd-managed session, otherwise graphical-session.target never
      # activates and xremap never starts
      withUWSM = true;
    };
    programs.uwsm.waylandCompositors.hyprland = {
      prettyName = "Hyprland";
      comment = "hyprland managed by uwsm";
      # not /run/wrappers/bin/Hyprland: uwsm rejects it as unreadable
      binPath = "/run/current-system/sw/bin/Hyprland";
    };
    xdg.portal = {
      # xdgOpenUsePortal = true; # this seems to override my .desktop definitions in home-manager?
      enable = true;
      extraPortals = [
        (lib.mkIf gnome_enabled pkgs.xdg-desktop-portal-gnome)
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
        user = config.machine.user;
      };
      sddm = {
        enable = true;
        wayland.enable = true;
        # enableHidpi = true;
        settings.General.DisplayServer = "wayland";
      };
      # defaultSession = "hyprland";
      defaultSession = if gnome_enabled then "gnome" else "hyprland-uwsm";
      # defaultSession = "niri";
      # defaultSession = "plasma";
      # defaultSession = "cosmic";
    };
    services.desktopManager.plasma6.enable = constants.enable_plasma && !config.machine.low_resources;
    environment.etc."xdg/baloofilerc" = lib.mkIf constants.enable_plasma {
      source = (pkgs.formats.ini {}).generate "baloorc" {
        "Basic Settings" = {
          "Indexing-Enabled" = false;
        };
      };
    };
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      spectacle # to avoid building opencv
    ];
    programs.niri.enable = true;

    # cosmic DE
    # services.desktopManager.cosmic.enable = true;
    # services.displayManager.cosmic-greeter.enable = true;

    # tty configs
    # console = {
    #   earlySetup = true;
    #   font = "ter-i14b";
    #   packages = with pkgs; [ terminus_font ];
    #   useXkbConfig = true; # remap caps to escape
    # };
    security.audit.enable = !config.machine.low_resources;
    security.auditd.enable = !config.machine.low_resources;

    # ask for password in terminal instead of x11-ash-askpass
    programs.ssh.askPassword = "";

    # enable some programs/services
    services.printing.enable = !config.machine.low_resources; # CUPS
    services.touchegg.enable = !config.machine.low_resources;
    programs.thunar = lib.mkIf (!config.machine.is_vm && !config.machine.low_resources) {
      enable = true;
      plugins = with pkgs.xfce; [
        thunar-archive-plugin
        thunar-media-tags-plugin
        thunar-volman
      ];
    };
    programs.xfconf.enable = !config.machine.low_resources;
    services.tumbler.enable = lib.mkForce false;

    # hybrid sleep when press power button. doesnt work anymore
    # services.logind.extraConfig = ''
    #   HandlePowerKey=ignore
    #   IdleAction=ignore
    #   IdleActionSec=1m
    # '';
    # dont hibernate when lid is closed
    services.logind.lidSwitch = "ignore";

    # spice-gtk?
    programs.virt-manager.enable = !config.machine.low_resources;
    users.groups.libvirtd.members = lib.mkIf (!config.machine.low_resources) [ config.machine.user ];
    virtualisation.spiceUSBRedirection.enable = !config.machine.low_resources;

    # dictionaries
    services.dictd.enable = !config.machine.low_resources;
    services.dictd.DBs = with pkgs.dictdDBs; [ wiktionary wordnet ];
    environment.wordlist.enable = !config.machine.low_resources;

    documentation.dev.enable = !config.machine.low_resources;

    # needed for uvx too
    programs.nix-ld = {
      enable = true;
      libraries = [
        pkgs.stdenv.cc.cc
        pkgs.zlib
        pkgs.openssl
        pkgs.stdenv.cc.cc.lib
      ] ++ pkgs.lib.optionals (!config.machine.low_resources) [
        # pkgs.python3Packages.torch.lib
        pkgs.fuse3
        pkgs.icu
        pkgs.nss
        pkgs.curl
        pkgs.expat
        pkgs.xorg.libX11
        pkgs.libGL
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
      # overwrite notify-send to not let anything handle notifications
      (pkgs.writeShellScriptBin "notify-send" ''
        echo $@ > /tmp/notif
      '')

      zathura
      pavucontrol
      alsa-utils
      playerctl # media control

      # wayland
      wl-clipboard
      grim slurp # for screenshots
      brightnessctl
      libnotify
      swww # wallpaper setter
    ] ++ pkgs.lib.optionals (!config.machine.low_resources) [
      gtkpython

      # code-cursor windsurf

      vulkan-tools mesa-demos

      # media tools
      # feh # image viewer (can it set wallpaper on wayland?)
      kdePackages.okular foliate mupdf
      ocrmypdf pdftk pdfgrep poppler-utils
      imv # nice image viewer
      spotube # open source spotify client?
      inkscape

      scrcpy
      libreoffice
      pulsemixer # tui for pulseaudio control
      gptfdisk parted
      libtool # to compile vterm
      btrfs-progs

      wf-recorder
      iio-hyprland
      wvkbd # onboard alternative (on-screen keyboard)
      wl-screenrec
      # digikam # another image viewer?

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

      woeusb-ng
      quickemu # quickly start VMs
      acpi lm_sensors
      cryptsetup
      # jellycli
    ];

    services.xremap = {
      enable = true;
      withWlroots = true;
      package = pkgs.xremap;
      serviceMode = "user";
      userName = config.machine.user;
      watch = true;
      config = {
        modmap = [{
          name = "global";
          remap = {
            CapsLock = "Esc";
            Alt_R = "Ctrl_L";
          };
        }];
        keymap = [{
          name = "global";
          remap = {
            "Super-Enter".launch = [ "${spawn}/bin/spawn" "wezterm" "--config-file" "/home/${config.machine.user}/.config/wezterm/wezterm.lua" ];
            "Super-Shift-Enter".launch = [ "${spawn}/bin/spawn" "wezterm" "connect" "mahmooz2" ];
            "Super-r".launch = [ "${spawn}/bin/spawn" "run.sh" ];
            "Super-p".launch = [ "${spawn}/bin/spawn" "myscrot.sh" ];
            "Super-Shift-p".launch = [ "${spawn}/bin/spawn" "myscrot.sh" "1" ];
            "Super-x" = {
              timeout_millis = 2000;
              remap = {
                w.launch = [ "${spawn}/bin/spawn" "firefox" ];
                e.launch = [ "${spawn}/bin/spawn" "emacs" ];
                c.launch = [ "${spawn}/bin/spawn" "code" ];
                x.launch = [ "${spawn}/bin/spawn" "xournalpp" ];
                j.launch = [ "${spawn}/bin/spawn" "jellyfinmediaplayer" ];
                l.launch = [ "${spawn}/bin/spawn" "lem" ];
                k.launch = [ "${spawn}/bin/spawn" "kill_process.sh" ];
                b.launch = [ "${spawn}/bin/spawn" "web_bookmarks.sh" ];
                o.launch = [ "${spawn}/bin/spawn" "terminal_with_cmd.sh" "glances" ];
                p.launch = [ "${spawn}/bin/spawn" "terminal_with_cmd.sh" "pulsemixer" ];
                i.launch = [ "${spawn}/bin/spawn" "${pkgs.dash}/bin/dash" "-lc" "cd ~/data/images/scrots/; ls -t --color=no | imv -d" ];
                a.launch = [ "${spawn}/bin/spawn" "${pkgs.dash}/bin/dash" "-lc" ''HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances | head -1 | cut -d " " -f2 | tr -d ":") sh -c "cd ${work_dir}/widgets; nix-shell --run \"python bar.py\""'' ];
                t = [ "C-c" "h" "e" "l" "l" "o" ];
              };
            };
          };
        }];
      };
    };

    # the unit's default PATH has none of these, so the launches above ENOENT
    systemd.user.services.xremap.path = [
      "/run/wrappers"
      "/etc/profiles/per-user/${config.machine.user}"
      "/run/current-system/sw"
      "/home/${config.machine.user}/.local"
    ];

    # without this okular is blurry
    environment.sessionVariables.QT_QPA_PLATFORM = "wayland";

    # make disablewhiletyping and other settings work with xremap (libevdev-based key remapper, https://github.com/rvaiya/keyd/issues/66#issuecomment-985983524)
    environment.etc."libinput/local-overrides.quirks".text = pkgs.lib.mkForce ''
      [Serial Keyboards]
      MatchUdevType=keyboard
      MatchName=xremap*
      AttrKeyboardIntegration=internal
    '';

    services.udev.extraRules = ''
      SUBSYSTEM=="block", ENV{ID_FS_UUID}=="777ddbd7-9692-45fb-977e-0d6678a4a213", RUN+="${pkgs.coreutils}/bin/mkdir -p /home/mahmooz/mnt" RUN+="${pkgs.systemd}/bin/systemd-mount $env{DEVNAME} /home/mahmooz/mnt/", RUN+="${lib.getExe pkgs.logger} --tag my-manual-usb-mount udev rule success, drive: %k with uuid $env{ID_FS_UUID}"
      SUBSYSTEM=="block", ENV{ID_FS_UUID}=="be5af23f-da6d-42ee-a346-5ad3af1a299a", RUN+="${pkgs.coreutils}/bin/mkdir -p /home/mahmooz/mnt2" RUN+="${pkgs.systemd}/bin/systemd-mount $env{DEVNAME} /home/mahmooz/mnt2", RUN+="${lib.getExe pkgs.logger} --tag my-manual-usb-mount udev rule success, drive: %k with uuid $env{ID_FS_UUID}"
    '';

    powerManagement = {
      enable = true;
      powertop.enable = !config.machine.low_resources;
      cpuFreqGovernor = "ondemand";
    };

    # helps finding the package that contains a specific file
    programs.nix-index = {
      enable = !config.machine.low_resources;
      enableZshIntegration = true;
      enableBashIntegration = true;
    };
    programs.command-not-found.enable = false; # needed for nix-index

    programs.dconf.enable = true;

    services.spice-webdavd.enable = !config.machine.low_resources;
    services.qemuGuest.enable = !config.machine.low_resources;
    services.spice-vdagentd.enable = !config.machine.low_resources;
  };
}