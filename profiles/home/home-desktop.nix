{ lib, pkgs, config, config', pkgs-pinned, ... }:

let
  constants = (import ../lib/constants.nix);
in
{
  imports = [
    ./karabiner.nix
  ];

  config = lib.mkMerge [
    (lib.mkIf config'.machine.is_desktop {
      programs.mpv = {
        enable = true;
        scripts = [
          pkgs.mpvScripts.memo
        ];
      };
      home.packages = with pkgs; [
      ];
    })

    (lib.mkIf (config'.machine.is_linux && config'.machine.is_desktop) {
      services.blueman-applet.enable = true;
      services.playerctld.enable = true;
      services.mpris-proxy.enable = true;

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

      # use 'dconf dump /' or 'gsettings list-recursively | less' to get a list of options
      dconf = lib.mkIf config'.machine.is_linux {
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
        gtk.enable = config'.machine.is_desktop;
        # x11.enable = true;
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Classic";
        size = 16;
      };

      gtk = {
        enable = config'.machine.is_desktop;
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

      # qt = {
      #   enable = config'.machine.is_desktop;
      #   platformTheme.name = "kde";
      #   style.package = pkgs.adwaita-qt;
      # };
    })

    (lib.mkIf (config'.machine.is_darwin && config'.machine.is_desktop) {
    })
  ];
}