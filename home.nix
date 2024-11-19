{ config, pkgs, ... }:

let
  desktop_vars = (import ./desktop_vars.nix { pkgs = pkgs; });
in
{
  wayland.windowManager.hyprland = {
    enable = true; # enable Hyprland
    package = pkgs.hyprland;
    plugins = [
      pkgs.hyprlandPlugins.hyprfocus

      # pkgs.hyprlandPlugins.hyprscroller
      # pkgs.hyprlandPlugins.hyprspace
      # pkgs.hyprlandPlugins.borders-plus-plus

      # pkgs.hyprlandPlugins.hypr-dynamic-cursors
      # pkgs.hyprlandPlugins.hy3
      # pkgs.hyprlandPlugins.hyprgrass
      # pkgs.hyprlandPlugins.hyprcursor
      # pkgs.hyprlandPlugins.hyprbars # buggy
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
      };
      # you need quotes to escape '/'
      "org/gnome/desktop/interface" = {
        clock-show-weekday = true;
        color-scheme = "prefer-dark";
        gtk-theme = "Adwaita-dark";
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

  home.file.".ssh/authorized_keys" = { text = ''
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICQaNODbg0EX196+JkADTx/cB0arDn6FelMGsa0tD0p6 mahmooz@mahmooz
  ''; };
}