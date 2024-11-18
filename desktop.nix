{ config, pkgs, lib, ... }:

let
  server_vars = (import ./server_vars.nix { pkgs = pkgs; });
  desktop_vars = (import ./desktop_vars.nix { pkgs = pkgs; });
  per_machine_vars = (import ./per_machine_vars.nix {});
in
{
  imports = [
    ./server.nix
  ] ++ lib.optional (per_machine_vars.enable_nvidia) ./nvidia.nix;

  # automatic screen rotation?
  hardware.sensor.iio.enable = true;

  services.iptsd.enable = true;
  services.iptsd.config.Touch.DisableOnStylus = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.nvidia.open = false;

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
  security.rtkit.enable = true; # Realtime audio support
  services.pipewire.enable = lib.mkForce false;
  hardware.pulseaudio = {
    enable = true;
    # extraModules = [ pkgs.pulseaudio-modules-bt ];
    package = pkgs.pulseaudioFull;
    extraConfig = "
      load-module module-switch-on-connect
    ";
  };
  systemd.user.services.mpris-proxy = {
    description = "mpris proxy";
    after = [ "network.target" "sound.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
  };

  nixpkgs.config.cudaSupport = per_machine_vars.enable_nvidia;

  # my overlays
  nixpkgs.overlays = [
    # for ags
    (final: prev:
    {
      ags = prev.ags.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [ pkgs.libdbusmenu-gtk3 pkgs.libnotify pkgs.gtksourceview pkgs.libgedit-gtksourceview ];
      });
    })
    (self: super: {
      mypython = super.python3.withPackages (ps: with ps; [
        python-magic
        requests
        paramiko pynacl # for find_computers.py (latter is needed for former)

        # ML
        # numpy
        # pytorch
        # matplotlib
      ]);
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
    (final: prev: { cudaPackages = final.cudaPackages_12_3; })
  ] ++ server_vars.server_overlays;

  # x11 and awesomewm
  services.xserver = {
    enable = true;
    # wacom.enable = true;
    displayManager.gdm.enable = true;
    # displayManager.sddm.enable = true;
    # desktopManager.gnome.enable = true;
    # desktopManager.xfce.enable = true;
    # desktopManager.plasma6.enable = true;
    displayManager = {
      sessionCommands = ''
        # some of these commands dont work because $HOME isnt /home/mahmooz..
        # ${lib.getExe pkgs.hsetroot} -solid '#222222' # incase wallpaper isnt set
        # ${lib.getExe pkgs.xorg.xrdb} -load /home/mahmooz/.Xresources
        # ${lib.getExe pkgs.feh} --bg-fill /home/mahmooz/.cache/wallpaper
      '';
      # startx.enable = true;
      # sx.enable = true;
    };
    xkb.layout = "us,il,ara";
    xkb.options = "caps:escape,ctrl:ralt_rctrl";
    # windowManager.awesome = {
    #   package = with pkgs; my_awesome;
    #   enable = true;
    #   luaModules = with pkgs.luaPackages; [
    #     luarocks
    #   ];
    # };
  };
  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "mahmooz";
    };
    # defaultSession = "none+awesome";
    # defaultSession = "xfce+awesome";
    # defaultSession = "xfce";
    defaultSession = "hyprland";
    # defaultSession = "gnome";
    # defaultSession = "plasma";
  };
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

  # tty configs
  console = {
    #earlySetup = true;
    font = "ter-i14b";
    packages = with pkgs; [ terminus_font ];
    useXkbConfig = true; # remap caps to escape
  };
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
    execWheelOnly = true;
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
  programs.firefox.enable = true;
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

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      fantasque-sans-mono
      google-fonts
      cascadia-code
      inconsolata-nerdfont
      iosevka
      fira-code
      nerdfonts
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
      # corefonts # MS fonts?
      mplus-outline-fonts.githubRelease
      dina-font
      proggyfonts
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

  services.ollama = {
    enable = per_machine_vars.enable_nvidia;
    acceleration = "cuda";
  };

  # self-hosted media service
  services.jellyfin.enable = true;

  # packages
  environment.systemPackages = with pkgs; [
    (pkgs.writeShellScriptBin "python" ''
      export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
      exec ${pkgs.mypython}/bin/python "$@"
    '')
    (pkgs.writeShellScriptBin "python3" ''
      export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
      exec ${pkgs.mypython}/bin/python "$@"
    '')

    # text editors
    vscode
    neovim

    # media tools
    mpv
    vlc
    feh # i use it to set wallpaper
    my_sxiv # qimgv
    telegram-desktop
    youtube-music
    okular zathura foliate mupdf
    xournalpp # pkgs.adwaita-icon-theme # the icon theme is needed for xournalpp to work otherwise it crashes
    # krita
    # lollypop clementine
    ocrmypdf pdftk pdfgrep poppler_utils djvu2pdf fntsample #calibre
    djvulibre
    qimgv
    jellyfin jellyfin-web jellyfin-ffmpeg

    # media manipulation tools
    inkscape # gimp

    # general tools
    # google-chrome nyxt tor-browser-bundle-bin # qutebrowser
    brave tor-browser-bundle-bin google-chrome
    scrcpy
    pavucontrol
    libreoffice
    # neovide

    # commandline tools
    wezterm # terminal emulator
    kitty
    pulsemixer # tui for pulseaudio control
    alsa-utils
    playerctl # media control
    gptfdisk parted
    libtool # to compile vterm
    xdotool
    btrfs-progs
    sshpass

    # x11 tools
    rofi
    libnotify
    xclip xsel
    maim # maim is a better alternative to scrot
    hsetroot
    unclutter
    xorg.xev
    sxhkd
    xorg.xwininfo
    xorg.xauth

    # wayland
    gnomeExtensions.xremap
    wl-clipboard
    waybar
    grim slurp # for screenshots
    wofi
    eww
    brightnessctl
    swww
    wf-recorder
    ydotool
    hyprpicker
    iio-hyprland
    swappy # for quick snapshot image editing
    wvkbd # onboard alternative (on-screen keyboard)

    # other
    zoom-us #, do i realy want this running natively?
    hugo
    adb-sync
    # woeusb-ng
    ntfs3g
    gnupg1orig
    SDL2
    sass
    simplescreenrecorder
    usbutils
    pciutils
    subversion # git alternative
    # logseq
    graphviz
    firebase-tools
    graphqlmap
    isync
    notmuch
    nuclear
    python312Packages.google
    # popcorntime
    stremio
    syncthing
    ags

    # local model stuff?
    koboldcpp
    jan

    soulseekqt
    nicotine-plus

    # for listening to radio music?
    strawberry
    shortwave

    # scientific computation?
    gnuplot
    lean
    sentencepiece
    # sageWithDoc sagetex
    kaggle google-cloud-sdk python3Packages.huggingface-hub python3Packages.datasets

    # quickly start VMs
    quickemu

    # some programming languages/environments
    (lua.withPackages(ps: with ps; [ busted luafilesystem luarocks ]))
    flutter dart android-studio android-tools genymotion
    texlive.combined.scheme-full
    rustc meson ninja
    # jupyter
    typescript
    desktop_vars.desktop_julia
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
    nodePackages.vim-language-server
    nodePackages.bash-language-server
    nil # nixd
    texlab
    sqls
    ruff-lsp
    python3Packages.python-lsp-server
    nodePackages_latest.typescript-language-server
    nodePackages_latest.eslint
    vscode-langservers-extracted

    # dictionary
    (aspellWithDicts (dicts: with dicts; [ en en-computers en-science ]))
    # enchant.dev # for emacs jinx-mode

    cudatoolkit # although i should only enable it if per_machine_vars.enable_nvidia is true
    nvtopPackages.full

    liquidctl
  ] ++ server_vars.server_packages;

  services.prometheus = {
    enable = true;
    port = 9001;
  };
  # services.monit.enable = true;

  # run sxhkd when x11 starts
  # systemd.user.services.my_sxhkd_service = {
  #   wantedBy = [ "graphical-session.target" ];
  #   partOf = [ "graphical-session.target" ];
  #   serviceConfig = {
  #     ExecStart = "${lib.getExe pkgs.sxhkd}";
  #   };
  # };

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

  systemd.services.my_syncthing = {
    description = "mpv logger";
    wantedBy = [ "multi-user.target" ];
    script = "${pkgs.syncthing}/bin/syncthing --home=/home/mahmooz/.syncthing_config";
    serviceConfig = {
      User = "mahmooz";
    };
  };

  # for keyd
  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = [ "*" ]; # what goes into the [id] section, here we select all keyboards
          # everything but the ID section:
          settings = {
            # the main layer, if you choose to declare it in Nix
            main = {
              capslock = "esc"; # you might need to also enclose the key in quotes if it contains non-alphabetical symbols
              rightalt = "leftcontrol";
            };
            otherlayer = {};
          };
        extraConfig = ''
            # put here any extra-config, e.g. you can copy/paste here directly a configuration, just remove the ids part
          '';
      };
    };
  };
  # optional, but makes sure that when you type the make palm rejection work with keyd
  # https://github.com/rvaiya/keyd/issues/723
  environment.etc."libinput/local-overrides.quirks".text = ''
    [Serial Keyboards]
    MatchUdevType=keyboard
    MatchName=keyd virtual keyboard
    AttrKeyboardIntegration=internal
  '';

  system.stateVersion = "24.05"; # dont change
}