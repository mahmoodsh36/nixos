{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    inputs.niri-flake.nixosModules.niri
  ];

  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

  environment.systemPackages = with pkgs; [
    fuzzel
    kitty
    swaybg
    swaylock
    xwayland-satellite
  ];

  home-manager.users."${config.machine.user}" = { config, lib, pkgs, ... }: {
    programs.niri.settings = {
      prefer-no-csd = true;

      input = {
        keyboard.xkb = {
          layout = "us";
          options = "compose:ralt";
        };
        touchpad = {
          tap = true;
          natural-scroll = true;
        };
      };

      layout = {
        gaps = 16;
        center-focused-column = "never";

        preset-column-widths = [
          { proportion = 1.0 / 3.0; }
          { proportion = 1.0 / 2.0; }
          { proportion = 2.0 / 3.0; }
        ];

        default-column-width = { proportion = 1.0 / 2.0; };

        focus-ring = {
          enable = true;
          width = 4;
          active.color = "#7fc8ff";
          inactive.color = "#505050";
        };
      };

      spawn-at-startup = [
        { command = [ "xwayland-satellite" ]; }
        { command = [ "swaybg" "-c" "#333333" ]; }
      ];

      binds = with config.lib.niri.actions; {
        "Mod+Shift+Slash".action = show-hotkey-overlay;

        # application launching
        "Mod+D".action.spawn = [ "fuzzel" ];
        "Mod+Return".action.spawn = [ "kitty" ];
        "Mod+W".action.spawn = [ "wezterm" ];
        "Mod+Shift+E".action = quit;

        # window management
        "Mod+Q".action = close-window;
        "Mod+F".action = maximize-column;
        "Mod+Shift+F".action = fullscreen-window;
        "Mod+C".action = center-column;

        # focus
        "Mod+H".action = focus-column-left;
        "Mod+L".action = focus-column-right;
        "Mod+J".action = focus-window-down;
        "Mod+K".action = focus-window-up;
        "Mod+Left".action = focus-column-left;
        "Mod+Right".action = focus-column-right;
        "Mod+Down".action = focus-window-down;
        "Mod+Up".action = focus-window-up;

        # movement
        "Mod+Shift+H".action = move-column-left;
        "Mod+Shift+L".action = move-column-right;
        "Mod+Shift+J".action = move-window-down;
        "Mod+Shift+K".action = move-window-up;
        "Mod+Shift+Left".action = move-column-left;
        "Mod+Shift+Right".action = move-column-right;
        "Mod+Shift+Down".action = move-window-down;
        "Mod+Shift+Up".action = move-window-up;

        # monitor focus
        "Mod+Shift+Comma".action = focus-monitor-left;
        "Mod+Shift+Period".action = focus-monitor-right;
        "Mod+Shift+Less".action = move-column-to-monitor-left;
        "Mod+Shift+Greater".action = move-column-to-monitor-right;

        # column/window sizing
        "Mod+R".action = switch-preset-column-width;
        "Mod+Minus".action = set-column-width "-10%";
        "Mod+Equal".action = set-column-width "+10%";

        # utilities
        "Print".action.screenshot = [];
        "Ctrl+Print".action.screenshot-screen = [];
        "Alt+Print".action.screenshot-window = [];
      };
    };
  };
}