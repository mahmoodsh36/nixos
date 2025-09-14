{ config, pkgs, lib, inputs, ... }:

let
  desktop_vars = (import ../lib/desktop-vars.nix { pkgs = pkgs; inputs = inputs; });
  constants = (import ../lib/constants.nix);

  dots = if builtins.pathExists "${config.home.homeDirectory}/work/otherdots"
         then "${config.home.homeDirectory}/work/otherdots"
         else (builtins.fetchGit {
           url = "${constants.mygithub}/otherdots.git";
           ref = "main";
         }).outPath;

  nvim_dots = if builtins.pathExists "${config.home.homeDirectory}/work/nvim"
         then "${config.home.homeDirectory}/work/nvim"
         else (builtins.fetchGit {
           url = "${constants.mygithub}/nvim.git";
           ref = "main";
         }).outPath;

  config_names = [
    "mimeapps.list" "mpv" "vifm" "user-dirs.dirs" "zathura" "wezterm"
    "xournalpp" "imv" "hypr" "goose" "aichat"
  ];
  config_entries = lib.listToAttrs (builtins.map (cfg_name: {
    name = ".config/${cfg_name}";
    value = {
      source = config.lib.file.mkOutOfStoreSymlink "${dots}/.config/${cfg_name}";
      force = true;
    };
  }) config_names);

  scripts_dir = if builtins.pathExists "${config.home.homeDirectory}/work/scripts"
         then "${config.home.homeDirectory}/work/scripts"
         else (builtins.fetchGit {
           url = "${constants.mygithub}/scripts.git";
           ref = "main";
         }).outPath;
  scripts = builtins.attrNames (builtins.readDir scripts_dir);
  script_files = builtins.filter (name: builtins.match ".*\\.(py|sh|el)$" name != null) scripts;

  script_entries = lib.listToAttrs (builtins.map (fname: {
    name  = ".local/bin/${fname}";
    value = {
      source = config.lib.file.mkOutOfStoreSymlink "${scripts_dir}/${fname}";
      force = true;
      # executable = true;
    };
  }) script_files);
in
{
  imports = [
    ../modules/machine-options.nix
    ./vscode.nix
    ./zed.nix
    ./distrobox-config.nix
    ./plasma.nix
  ];

  config = {
    _module.args = { pkgs-pinned = inputs.pkgs-pinned; };

    /* the home.stateVersion option does not have a default and must be set */
    home.stateVersion = "24.05";

    home.file = config_entries // script_entries // {
      ".zshrc" = {
        source = config.lib.file.mkOutOfStoreSymlink "${dots}/.zshrc";
      };
      ".zprofile" = {
        source = config.lib.file.mkOutOfStoreSymlink "${dots}/.zprofile";
      };
      ".config/nvim" = {
        source = config.lib.file.mkOutOfStoreSymlink nvim_dots;
      };
    };

    programs.home-manager.enable = true;

    # i dont think im even making use of this
    programs.neovim = {
      enable = true;
      plugins = with pkgs.vimPlugins; [
        nvim-treesitter.withAllGrammars
      ];
      # viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      # withNodeJs = true;
      withPython3 = true;
    };

    services.blueman-applet.enable = config.machine.is_desktop;
    services.playerctld.enable = config.machine.is_desktop;
    services.parcellite.enable = config.machine.is_desktop;

    home.packages = with pkgs; [
      # to avoid some errors
      dconf
    ];

    programs.git = {
      enable = true;
      userName = "mahmoodsh36";
      userEmail = "mahmod.m2015@gmail.com";
    };

    xdg.desktopEntries.mympv = {
      name = "mympv";
      genericName = "mympv";
      exec = "mympv.sh %F";
      terminal = false;
      icon = "mpv";
      categories = [ "AudioVideo" "Audio" "Video" "Player" "TV" ];
      type = "Application";
      # mimeTypes = [ "video/mp4" ];
    };
    xdg.desktopEntries.add_magnet = {
      name = "add_magnet";
      genericName = "add_magnet";
      exec = '' add_magnet.sh %u '';
      terminal = false;
      categories = [];
      mimeType = [ "x-scheme-handler/magnet" ];
      type = "Application";
    };

    programs.firefox = {
      enable = config.machine.is_desktop;
    };

    # use 'dconf dump /' or 'gsettings list-recursively | less' to get a list of options
    dconf = {
      enable = true;
      settings = {
        # for virt-manager, https://nixos.wiki/wiki/Virt-manager
        "org/virt-manager/virt-manager/connections" = {
          autoconnect = [ "qemu:///system" ];
          uris = [ "qemu:///system" ];
        };

        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = with pkgs.gnomeExtensions; [
            blur-my-shell.extensionUuid
            gsconnect.extensionUuid
            paperwm.extensionUuid
          ];
          favorite-apps = [
            "firefox.desktop"
            "emacs.desktop"
            "org.gnome.Nautilus.desktop"
          ];
        };
        "org/gnome/desktop/wm/preferences" = {
          resize-with-right-button = true;
        };
        "org/gnome/desktop/peripherals/mouse" = {
          natural-scroll = true;
        };
        "org/gnome/desktop/session" = {
          idle-delay = lib.hm.gvariant.mkUint32 0;
        };
        "org/gnome/desktop/screensaver" = {
          lock-enabled = false;
          logout-enabled = false;
          logout-delay = lib.hm.gvariant.mkUint32 0;
        };
        "org/gnome/shell/app-switcher" = {
          current-workspace-only = true;
        };
        "org/gnome/desktop/wm/keybindings" = {
          switch-to-workspace-1 = ["<Super>1"];
          switch-to-workspace-2 = ["<Super>2"];
          switch-to-workspace-3 = ["<Super>3"];
          switch-to-workspace-4 = ["<Super>4"];
          move-to-workspace-1 = ["<Super><Shift>1"];
          move-to-workspace-2 = ["<Super><Shift>2"];
          move-to-workspace-3 = ["<Super><Shift>3"];
          move-to-workspace-4 = ["<Super><Shift>4"];
          switch-to-application-1 = "disabled";
          switch-to-application-2 = "disabled";
          switch-to-application-3 = "disabled";
          switch-to-application-4 = "disabled";
          close = ["<Super>q"];
          minimize = ["<Super>n"];
          toggle-maximized = ["<Super>m"];
          toggle-message-tray = "disabled";
          activate-window-menu = ["<Super>`"];
        };
        "org/gnome/desktop/peripherals/touchpad" = {
          tap-to-click = true;
          two-finger-scrolling-enabled = true;
        };
        # could be creating .gtkrc-2 and interfering with plasma-manager, not sure
        # "org/gnome/desktop/interface" = {
        #   clock-show-seconds = true;
        #   clock-show-weekday = true;
        #   color-scheme = "prefer-dark";
        #   gtk-theme = "Adwaita-dark";
        #   scaling-factor = lib.hm.gvariant.mkUint32 0; # 0 to automatically detect
        #   enable-hot-corners = false;
        #   show-battery-percentage = true;
        # };
        "org/gnome/settings-daemon/plugins/media-keys" = {
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          ];
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          binding = "<Super>Return";
          command = "kitty";
          name = "open-terminal";
        };
      };
    };

    home.pointerCursor = {
      gtk.enable = config.machine.is_desktop;
      # x11.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 16;
    };

    gtk = {
      enable = config.machine.is_desktop;
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
      iconTheme = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
      };
      cursorTheme = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
      };
    };

    qt = {
      enable = config.machine.is_desktop;
      platformTheme.name = "kde6";
      style.package = pkgs.adwaita-qt;
    };
  };
}