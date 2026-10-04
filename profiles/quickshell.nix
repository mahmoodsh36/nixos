{ lib, config, pkgs, ... }:

# everything quickshell needs in one place: the system service its widgets
# read, and the home-manager shell itself.
let
  user = config.machine.user;
  home = config.users.users.${user}.home;
in
{
  config = lib.mkIf (config.machine.is_linux && config.machine.is_desktop) {
    services.upower.enable = true;
    fonts.packages = [ pkgs.material-symbols ];

    home-manager.users.${user} = {
      programs.quickshell = {
        enable = true;
        configs.default = ./quickshell;
        activeConfig = "default";
        # starts with graphical-session.target, which uwsm manages for hyprland
        systemd.enable = true;
      };

      home.packages = [ pkgs.brightnessctl ];

      # user manager PATH is minimal, launched apps inherit this
      systemd.user.services.quickshell.Service.Environment = [
        "PATH=/run/wrappers/bin:/etc/profiles/per-user/${user}/bin:${home}/.nix-profile/bin:${home}/.local/bin:/run/current-system/sw/bin"
        # for the calendar's cltpt agenda
        "NOTES_DIR=${config.machine.voldir}/brain/notes"
      ];
    };
  };
}
