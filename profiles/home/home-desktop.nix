{ lib, pkgs, config, config', pkgs-pinned, ... }:

{
  imports = [
    ./karabiner.nix
  ];

  config = lib.mkMerge [
    (lib.mkIf config'.machine.is_desktop {
      # programs.mpv = {
      #   enable = true;
      #   scripts = [
      #     pkgs.mpvScripts.memo
      #   ];
      # };
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
        };
      };

      home.pointerCursor = {
        gtk.enable = config'.machine.is_desktop;
        # x11.enable = true;
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Classic";
        size = 16;
      };
    })

    (lib.mkIf (config'.machine.is_darwin && config'.machine.is_desktop) {
    })
  ];
}