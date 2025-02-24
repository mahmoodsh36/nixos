{ config, pkgs, lib, inputs, pinned-pkgs, ... }:

let
  server_vars = (import ./server_vars.nix { pkgs = pkgs; pinned-pkgs = pinned-pkgs; });
  desktop_vars = (import ./desktop_vars.nix { pkgs = pkgs; pinned-pkgs = pinned-pkgs; });
  per_machine_vars = (import ./per_machine_vars.nix {});
  mypython = desktop_vars.desktop_python;
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
  boot.kernelModules = [ "iwlwifi" ];
  boot.extraModprobeConfig = ''
    options iwlwifi power_save=0
  '';

  # tlp for battery saving? this heavily throttles my itnernet so im disabling it..
  # services.tlp = {
  #   enable = true;
  #   settings = {
  #     PLATFORM_PROFILE_ON_AC = "performance";
  #     PLATFORM_PROFILE_ON_BAT = "balanced";
  #     CPU_SCALING_GOVERNOR_ON_AC = "performance";
  #     CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
  #     CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
  #     CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
  #     CPU_BOOST_ON_AC=1;
  #     CPU_BOOST_ON_BAT=0;
  #     CPU_MAX_PERF_ON_AC = 100;
  #     CPU_MIN_PERF_ON_AC = 0;
  #     CPU_MAX_PERF_ON_BAT = 30;
  #     CPU_MIN_PERF_ON_BAT = 0;
  #     CPU_DRIVER_OPMODE_ON_AC = "active";
  #     CPU_DRIVER_OPMODE_ON_BAT = "active";
  #     STOP_CHARGE_THRESH_BAT1 = 80;
  #     USB_AUTOSUSPEND = 0;
  #     USB_BLACKLIST_WWAN = 1;
  #     WIFI_PWR_ON_AC = "off";
  #     WIFI_PWR_ON_BAT = "off";
  #     RESTORE_DEVICE_STATE_ON_STARTUP = 0;
  #     USB_ALLOWLIST = "46d:c07e";
  #     USB_EXCLUDE_BTUSB = 1;
  #     USB_EXCLUDE_PHONE = 1;
  #     RUNTIME_PM_BLACKLIST="0bda:8153"; # for ethernet port
  #   };
  #   # extraConfig = ''
  #   #   USB_AUTOSUSPEND=0
  #   # '';
  # };

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

  # my overlays

  nixpkgs.overlays = [
    (self: super:
    {
      llama-cpp = super.llama-cpp.overrideAttrs (oldAttrs: rec {
        src = super.fetchFromGitHub {
          owner = "ggerganov";
          repo = "llama.cpp";
          rev = "9d00bc21498a2d5235feab438eb4dc5490ec64d6";
          sha256 = "sha256-SFHYNK6d4+XzffCtZxKzFAEiU6vReAlV4yPuK/Vtm34=";
        };
      });
    })
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

    inputs.lem.packages.${pkgs.system}.lem-ncurses
    inputs.lem.packages.${pkgs.system}.lem-sdl2

    # media tools
    mpv
    vlc
    feh # i use it to set wallpaper
    telegram-desktop
    youtube-music
    kdePackages.okular zathura foliate mupdf
    xournalpp # rnote krita
    # krita
    lollypop clementine
    ocrmypdf pdftk pdfgrep poppler_utils djvu2pdf fntsample #calibre
    djvulibre
    jellyfin jellyfin-web jellyfin-ffmpeg jellyfin-media-player jellycli jellyfin-mpv-shim
    imv

    # media manipulation tools
    inkscape

    # general tools
    brave tor-browser-bundle-bin google-chrome
    scrcpy
    pavucontrol
    libreoffice
    neovide

    # commandline tools
    wezterm # kitty
    pulsemixer # tui for pulseaudio control
    alsa-utils
    playerctl # media control
    gptfdisk parted
    libtool # to compile vterm
    xdotool
    btrfs-progs
    sshpass

    # wayland
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
    libnotify
    darktable # image editor
    digikam # another image viewer?

    vdhcoapp # for firefox video download helper

    # other
    zoom-us #, do i realy want this running natively?
    hugo
    adb-sync
    woeusb-ng
    ntfs3g
    gnupg
    SDL2
    sass
    simplescreenrecorder
    usbutils
    pciutils
    subversion # git alternative
    graphviz
    isync
    notmuch
    stremio
    syncthing
    monolith # save webpages
    hoarder # wallabag
    liquidctl
    libinput
    bluez-tools blueman
    pulseaudioFull
    prettierd # for emacs apheleia
    nodePackages.prettier # for emacs apheleia
    black

    # scientific computation?
    gnuplot
    lean
    pinned-pkgs.sageWithDoc pinned-pkgs.sagetex
    kaggle google-cloud-sdk python3Packages.huggingface-hub python3Packages.datasets

    # quickly start VMs
    quickemu

    # some programming languages/environments
    (lua.withPackages(ps: with ps; [ busted luafilesystem luarocks ]))
    texlive.combined.scheme-full
    rustc meson ninja
    typescript
    desktop_vars.desktop_julia
    python3Packages.west
    typst
    tailwindcss
    poetry
    neo4j
    bun

    # lisps
    babashka
    chicken
    guile
    racket

    # offline docs
    # zeal devdocs-desktop

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
    enable = false; # per_machine_vars.enable_nvidia;
    description = "llama";
    wantedBy = [ "multi-user.target" ];
    script = "${pkgs.llama-cpp}/bin/llama-server --host 0.0.0.0 --port 8080 -m /home/mahmooz/models/DeepSeek-R1-Distill-Qwen-14B-Q8_0.gguf --host 0.0.0.0 --cache-type-k q8_0 --n-gpu-layers 50"; # -k q8_0 may be very important, https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF
    serviceConfig = {
      User = "mahmooz";
      # Restart = "always";
    };
  };

  services.ollama = {
    enable = per_machine_vars.enable_nvidia;
    package = pkgs.ollama-cuda;
    acceleration = "cuda";
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

  systemd.services.network-keepalive = {
    enable = true;
    description = "keep network connection alive using various network activities";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 5;
    };
    script = ''
      echo "=== Starting network keepalive ==="

      while true; do
        echo "renewing DHCP lease..."
        networkctl renew wlan0

        echo "flushing DNS cache..."
        resolvectl flush-caches

        echo "performing DNS lookups..."
        for server in 8.8.8.8 1.1.1.1 208.67.222.222 9.9.9.9; do
          echo "querying DNS via $server..."
          ${pkgs.dnsutils}/bin/dig @$server example.com +short || echo "DNS query failed for $server"
        done

        echo "sending ARP ping..."
        ${pkgs.iputils}/bin/arping -c 1 $(${pkgs.iproute2}/bin/ip route | ${pkgs.gawk}/bin/awk '/default/ {print $3}' | head -1)

        echo "pinging Google DNS..."
        ${pkgs.iputils}/bin/ping -c 1 8.8.8.8 || echo "Ping to 8.8.8.8 failed"

        echo "making an HTTP request..."
        ${pkgs.curl}/bin/curl -s --max-time 5 https://example.com > /dev/null || echo "HTTP request failed"

        echo "sleeping for 15 seconds..."
        sleep 15
      done
    '';
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