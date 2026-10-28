{ lib, config, pkgs, inputs, ... }:

# everything quickshell needs in one place: the system service its widgets
# read, and the home-manager shell itself. the qml lives in $work/quickshell.
let
  user = config.machine.user;
  home = config.users.users.${user}.home;
  live = "${config.machine.voldir}/work/quickshell";
in
{
  config = lib.mkIf (config.machine.is_linux && config.machine.is_desktop) {
    services.upower.enable = true;
    fonts.packages = [ pkgs.material-symbols ];

    home-manager.users.${user} = hm: {
      programs.quickshell = {
        enable = true;
        # starts with graphical-session.target, which uwsm manages for hyprland
        systemd.enable = true;
      };

      home.packages = with pkgs; [
        brightnessctl
        wlsunset # night light
        wf-recorder
        slurp
      ];

      # live checkout when present so edits hot reload, else the pinned input.
      # after linkGeneration so the old hm-managed dir is gone first.
      home.activation.linkQuickshell = hm.lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        target="$HOME/.config/quickshell"
        if [ -d "$target" ] && [ ! -L "$target" ]; then
          $DRY_RUN_CMD rm -f "$target/default"
          $DRY_RUN_CMD rmdir "$target"
        fi
        src="${inputs.quickshell-config}"
        [ -d "${live}" ] && src="${live}"
        $DRY_RUN_CMD ln -sfn "$src" "$target"
      '';

      # feeds the launcher's clipboard mode
      services.cliphist.enable = true;

      # user manager PATH is minimal, launched apps inherit this
      systemd.user.services.quickshell.Service.Environment = [
        "PATH=/run/wrappers/bin:/etc/profiles/per-user/${user}/bin:${home}/.nix-profile/bin:${home}/.local/bin:/run/current-system/sw/bin"
        # for the calendar's cltpt agenda
        "NOTES_DIR=${config.machine.voldir}/brain/notes"
      ];
    };
  };
}
