{ config, pkgs, lib, inputs, ... }:

let
  # xremap's .launch forks children directly, so they inherit its unit's
  # RestrictAddressFamilies=AF_UNIX seccomp filter and get no network.
  # --user makes the user manager fork instead; --scope would not, it
  # forks from the caller and keeps the filter.
  spawn = pkgs.writeShellScriptBin "spawn" ''
    cmd=$(command -v "$1") || { echo "spawn: $1 not found" >&2; exit 127; }
    shift
    exec ${pkgs.systemd}/bin/systemd-run --user --collect --quiet \
      --unit="spawn-$(basename "$cmd")-$$" --setenv=PATH="$PATH" \
      -- "$cmd" "$@"
  '';
in
{
  imports = [ inputs.xremap-flake.nixosModules.default ];

  config = lib.mkIf (config.machine.is_linux && config.machine.is_desktop) {
    services.xremap = {
      enable = true;
      withWlroots = true;
      package = pkgs.xremap;
      serviceMode = "user";
      userName = config.machine.user;
      watch = true;
      config = {
        modmap = [{
          name = "global";
          remap = {
            CapsLock = "Esc";
            Alt_R = "Ctrl_L";
          };
        }];
        keymap = [{
          name = "global";
          remap = {
            "Super-Enter".launch = [ "${spawn}/bin/spawn" "wezterm" "--config-file" "/home/${config.machine.user}/.config/wezterm/wezterm.lua" ];
            "Super-Shift-Enter".launch = [ "${spawn}/bin/spawn" "wezterm" "connect" "mahmooz2" ];
            "Super-r".launch = [ "${spawn}/bin/spawn" "${lib.getExe' pkgs.quickshell "qs"}" "ipc" "call" "launcher" "toggle" ];
            "Super-p".launch = [ "${spawn}/bin/spawn" "myscrot.sh" ];
            "Super-Shift-p".launch = [ "${spawn}/bin/spawn" "myscrot.sh" "1" ];
            "Super-x" = {
              timeout_millis = 2000;
              remap = {
                w.launch = [ "${spawn}/bin/spawn" "firefox" ];
                e.launch = [ "${spawn}/bin/spawn" "emacs" ];
                c.launch = [ "${spawn}/bin/spawn" "code" ];
                x.launch = [ "${spawn}/bin/spawn" "xournalpp" ];
                l.launch = [ "${spawn}/bin/spawn" "lem" ];
                k.launch = [ "${spawn}/bin/spawn" "kill_process.sh" ];
                b.launch = [ "${spawn}/bin/spawn" "web_bookmarks.sh" ];
                o.launch = [ "${spawn}/bin/spawn" "terminal_with_cmd.sh" "glances" ];
                p.launch = [ "${spawn}/bin/spawn" "terminal_with_cmd.sh" "pulsemixer" ];
                i.launch = [ "${spawn}/bin/spawn" "${pkgs.dash}/bin/dash" "-lc" "cd ~/data/images/scrots/; ls -t --color=no | imv -d" ];
                t = [ "C-c" "h" "e" "l" "l" "o" ];
              };
            };
          };
        }];
      };
    };

    # the unit's default PATH has none of these, so the launches above ENOENT
    systemd.user.services.xremap.path = [
      "/run/wrappers"
      "/etc/profiles/per-user/${config.machine.user}"
      "/run/current-system/sw"
      "/home/${config.machine.user}/.local"
    ];

    # make disablewhiletyping and other settings work with xremap (libevdev-based key remapper, https://github.com/rvaiya/keyd/issues/66#issuecomment-985983524)
    environment.etc."libinput/local-overrides.quirks".text = pkgs.lib.mkForce ''
      [Serial Keyboards]
      MatchUdevType=keyboard
      MatchName=xremap*
      AttrKeyboardIntegration=internal
    '';
  };
}
