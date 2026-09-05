{ lib, config, ... }:

# everything quickshell needs in one place: the system service its widgets
# read, and the home-manager shell itself.
{
  config = lib.mkIf (config.machine.is_linux && config.machine.is_desktop) {
    services.upower.enable = true;

    home-manager.users.${config.machine.user}.programs.quickshell = {
      enable = true;
      configs.default = ./quickshell;
      activeConfig = "default";
      # starts with graphical-session.target, which uwsm manages for hyprland
      systemd.enable = true;
    };
  };
}
