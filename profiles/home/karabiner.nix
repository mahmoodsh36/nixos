{ lib, pkgs, config, config', ... }:

let
  # Your helper functions remain the same
  swapKey = from: to: {
    type = "basic";
    from = {
      key_code = from;
      modifiers = { optional = [ "any" ]; };
    };
    to = [ { key_code = to; } ];
    conditions = [];
  };

  launchApp = key: app: {
    type = "basic";
    from = {
      key_code = key;
      modifiers = { mandatory = [ "left_command" ]; optional = [ "any" ]; };
    };
    to = [ { shell_command = "open -a " + app; } ];
    conditions = [];
  };

in
{
  # This option will now directly manage the main karabiner.json file
  home.file.karabiner-config = lib.mkIf (config'.machine.is_darwin && config'.machine.is_desktop) {
    # The target is now the main configuration file
    target = ".config/karabiner/karabiner.json";

    # The `text` needs to be a complete karabiner.json structure
    text = builtins.toJSON {
      global = {
        check_for_updates_on_startup = true;
        show_in_menu_bar = true;
        show_profile_name_in_menu_bar = false;
      };
      profiles = [
        {
          name = "Default";
          selected = true;
          complex_modifications = {
            parameters = {
              "basic.simultaneous_threshold_milliseconds" = 50;
              "basic.to_if_alone_timeout_milliseconds" = 1000;
              "basic.to_if_held_down_threshold_milliseconds" = 500;
              "basic.to_delayed_action_delay_milliseconds" = 500;
              "mouse_motion_to_scroll.speed" = 100;
            };
            # Your rules go directly here
            rules = [{
              description = "CapsLock → Escape, Right Cmd → Ctrl, App shortcuts";
              manipulators = [
                (swapKey "caps_lock" "escape")
                (swapKey "right_command" "left_control")
                (launchApp "return_or_enter" "WezTerm")
                (launchApp "f" "Firefox")
                (launchApp "e" "Emacs")
              ];
            }];
          };
          # You can also define simple_modifications, etc. here if needed
          simple_modifications = [];
        }
      ];
    };
  };
}