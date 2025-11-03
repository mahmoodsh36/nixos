{ lib, pkgs, config, config', ... }:

let
  swapKey = from: to: {
    type = "basic";
    from = {
      key_code = from;
      modifiers = { optional = [ "any" ]; };
    };
    to = [ { key_code = to; } ];   # inner set ends with semicolon
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
  home.file.karabiner = lib.mkIf (config'.machine.is_darwin && config'.machine.is_desktop) {
    target = ".config/karabiner/assets/complex_modifications/nix.json";
    text = builtins.toJSON {
      title = "Minimal Karabiner";
      rules = [{
        description = "CapsLock → Escape, Right Cmd → Ctrl, App shortcuts";
        manipulators = [
          (swapKey "caps_lock" "escape")
          (swapKey "right_command" "left_control")
          (launchApp "return_or_enter" "WezTerm")
          (launchApp "w" "Firefox")
          (launchApp "e" "Emacs")
        ];
      }];
    };
  };
}
