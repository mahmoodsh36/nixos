{ config, pkgs, lib, ... }:

let
  desktop_vars = (import ./desktop_vars.nix { pkgs = pkgs; });
in
{
  wayland.windowManager.hyprland = {
    enable = true; # enable Hyprland
    package = pkgs.hyprland;
    plugins = [
      pkgs.hyprlandPlugins.hyprfocus
      pkgs.hyprlandPlugins.hyprbars # buggy

      # pkgs.hyprlandPlugins.hyprscroller
      # pkgs.hyprlandPlugins.hyprspace
      # pkgs.hyprlandPlugins.borders-plus-plus

      # pkgs.hyprlandPlugins.hypr-dynamic-cursors
      # pkgs.hyprlandPlugins.hy3
      # pkgs.hyprlandPlugins.hyprgrass
      # pkgs.hyprlandPlugins.hyprcursor
      # pkgs.hyprlandPlugins.hyprtrails
      # pkgs.hyprlandPlugins.hyprwinwrap
    ];
    extraConfig = (builtins.readFile ./dots/hyprland.conf);
  };

  /* the home.stateVersion option does not have a default and must be set */
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;
  programs.neovim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
      coc-nvim coc-css coc-explorer coc-git coc-go coc-html coc-json coc-prettier coc-pyright coc-rust-analyzer coc-tsserver coc-yaml
      coc-clangd
      sqlite-lua
      coc-vimtex
      neoformat
      vim-commentary
      vim-monokai
      vimtex
      vim-nix
      vim-fugitive
    ];
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withNodeJs = true;
    withPython3 = true;
  };

  services.blueman-applet.enable = true;
  services.playerctld.enable = true;
  services.parcellite.enable = true;

  home.packages = [
  ];

  programs.git = {
    enable = true;
    userName = "mahmoodsheikh36";
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
    exec = "add_magnet.sh \"%F\"";
    terminal = false;
    categories = [];
    mimeType = [ "x-scheme-handler/magnet" ];
  };

  # use 'dconf dump /' or 'gsettings list-recursively | less' to get a list of options
  dconf = {
    enable = true;
    settings = {
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
      "org/gnome/desktop/interface" = {
        clock-show-seconds = true;
        clock-show-weekday = true;
        color-scheme = "prefer-dark";
        gtk-theme = "Adwaita-dark";
        scaling-factor = lib.hm.gvariant.mkUint32 0; # 0 to automatically detect
        enable-hot-corners = false;
        show-battery-percentage = true;
      };
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
    gtk.enable = true;
    # x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 16;
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "Adwaita-dark";
    style = {
      name = "Adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };
}