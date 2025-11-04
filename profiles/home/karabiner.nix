{ lib, pkgs, config, config', ... }:

let
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
  xdg.configFile."karabiner/HomeManagerInit_karabiner.json" = {
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
            rules = [
              {
                description = "CapsLock → Escape, Right Cmd → Ctrl, App shortcuts";
                manipulators = [
                  (swapKey "caps_lock" "escape")
                  (swapKey "right_command" "left_control") # right command to ctrl
                  # (swapKey "left_command" "left_option") # left command to alt
                  (launchApp "return_or_enter" "WezTerm")
                  (launchApp "b" "Firefox")
                  (launchApp "e" "Emacs")
                ];
              }
              {
                description = "Screenshot Shortcuts";
                manipulators = [
                  {
                    # full screen screenshot
                    from = {
                      key_code = "p";
                      modifiers = { mandatory = [ "left_command" ]; };
                    };
                    to = [{
                      shell_command = "screencapture -x ${config'.machine.voldir}/data/images/scrots/Screen-$(date +'%Y-%m-%d_%H.%M.%S').png";
                    }];
                    type = "basic";
                  }
                  {
                    from = {
                      key_code = "p";
                      modifiers = { mandatory = [ "left_command" "left_shift" ]; };
                    };
                    to = [{
                      # the command is the same but with the "-i" flag
                      shell_command = "screencapture -i -x ${config'.machine.voldir}/data/images/scrots/Screen-$(date +'%Y-%m-%d_%H.%M.%S').png";
                    }];
                    type = "basic";
                  }
                ];
              }
            ];
          };
          simple_modifications = [];
        }
      ];
    };
    # https://github.com/nix-community/home-manager/issues/3090#issuecomment-2010891733
    onChange = ''
      rm -f ${config.xdg.configHome}/karabiner/karabiner.json
      cp ${config.xdg.configHome}/karabiner/HomeManagerInit_karabiner.json ${config.xdg.configHome}/karabiner/karabiner.json
      chmod u+w ${config.xdg.configHome}/karabiner/karabiner.json
    '';
  };
}
