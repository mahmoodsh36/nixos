{ config, pkgs, ... }:

let
  desktop_vars = (import ./desktop_vars.nix { pkgs = pkgs; });
in
{
  home-manager = {
    users = let
      user_config = {

        /* the home.stateVersion option does not have a default and must be set */
        home.stateVersion = "23.05";

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

        home.pointerCursor = {
          name = "Adwaita";
          package = pkgs.adwaita-icon-theme;
          size = 64;
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
          categories="AudioVideo;Audio;Video;Player;TV";
          type = "Application";
          mimeTypes = [ "video/mp4" ];
        };
        xdg.desktopEntries.add_magnet = {
          name = "add_magnet";
          genericName = "add_magnet";
          exec = "add_magnet.sh \"%F\"";
          terminal = false;
          categories = [];
          mimeType = [ "x-scheme-handler/magnet" ];
        };

        home-manager.users.myuser = {
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
              # You need quotes to escape '/'
              "org/gnome/desktop/interface" = {
                clock-show-weekday = true;
                color-scheme = "prefer-dark";
              };
            }
          };
        };

        gtk = {
          enable = true;
          font.name = "Victor Mono SemiBold 12";
          theme = {
            name = "SolArc-Dark";
            package = pkgs.solarc-gtk-theme;
          };
        };
      };
    in {
      mahmooz = user_config;
      # root = user_config;
    };
  };
}