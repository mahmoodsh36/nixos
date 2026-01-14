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

  # Launch a macOS application by name, e.g. "Firefox" or "WezTerm"
  launchApp = key: app: {
    type = "basic";
    from = {
      key_code = key;
      modifiers = { mandatory = [ "left_command" ]; optional = [ "any" ]; };
    };
    to = [ { shell_command = "open -a " + lib.escapeShellArg app; } ];
    conditions = [];
  };

  # Run an arbitrary shell command (using bash -lc for proper environment)
  launchCommand = key: cmd: {
    type = "basic";
    from = {
      key_code = key;
      modifiers = { mandatory = [ "left_command" ]; optional = [ "any" ]; };
    };
    to = [ { shell_command = "bash -lc " + lib.escapeShellArg cmd; } ];
    conditions = [];
  };

  # Open the most recent screenshot file
  openLatestScreenshot = key: {
    type = "basic";
    from = {
      key_code = key;
      modifiers = { mandatory = [ "left_command" ]; optional = [ "any" ]; };
    };
    to = [{
      shell_command = "bash -lc 'latest=$(ls -t ${config'.machine.voldir}/data/images/scrots/*.png 2>/dev/null | head -n1); [ -n \"$latest\" ] && open \"$latest\"'";
    }];
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
                  (swapKey "right_command" "left_control")
                  (launchApp "b" "Firefox")
                  (launchApp "e" "Emacs")
                  (launchApp "u" "Youtube Music")
                  # (launchApp "return_or_enter" "WezTerm")
                  (launchCommand "return_or_enter" "export WEZTERM_CONFIG_FILE=$HOME/.config/wezterm/wezterm.lua; open -a wezterm")
                  (openLatestScreenshot "i")  # Opens latest screenshot with Cmd+L
                ];
              }
              {
                description = "Screenshot Shortcuts";
                manipulators = [
                  {
                    from = {
                      key_code = "p";
                      modifiers = { mandatory = [ "left_command" ]; };
                    };
                    to = [{
                      shell_command = "filepath=\"${config'.machine.voldir}/data/images/scrots/Screen-$(date +'%Y-%m-%d_%H.%M.%S').png\" && screencapture -x \"$filepath\" && printf \"%s\" \"$filepath\" | pbcopy";
                    }];
                    type = "basic";
                  }
                  {
                    from = {
                      key_code = "p";
                      modifiers = { mandatory = [ "left_command" "left_shift" ]; };
                    };
                    to = [{
                      shell_command = "filepath=\"${config'.machine.voldir}/data/images/scrots/Screen-$(date +'%Y-%m-%d_%H.%M.%S').png\" && screencapture -i -x \"$filepath\" && printf \"%s\" \"$filepath\" | pbcopy";
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

    # Ensure Karabiner uses this generated config
    onChange = ''
      rm -f ${config.xdg.configHome}/karabiner/karabiner.json
      cp ${config.xdg.configHome}/karabiner/HomeManagerInit_karabiner.json ${config.xdg.configHome}/karabiner/karabiner.json
      chmod u+w ${config.xdg.configHome}/karabiner/karabiner.json
    '';
  };
}