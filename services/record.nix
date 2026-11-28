{ config, pkgs, lib, self, ... }:

let
  record = self.packages.${pkgs.stdenv.hostPlatform.system}.record;
  mountGate = import ../lib/mount-gate.nix { inherit lib pkgs; };
  dataMount = mountGate.mountUnit config.machine.ext_data_dir;
  user = config.machine.user;
  fallback = "${config.machine.main_dir}/wc";
  out = "${config.machine.ext_data_dir}/wc";
  restartRecord = "-${pkgs.systemd}/bin/systemctl --user -M ${user}@ restart record";
in
{
  options.services.record.enable =
    lib.mkEnableOption "continuous segmented webcam recording";

  config = lib.mkIf config.services.record.enable {
    environment.systemPackages = [ record ];

    # runs in the user session so audio goes through pipewire; lingering starts
    # that session (and pipewire) at boot without a login.
    users.users.${user} = {
      linger = true;
      extraGroups = [ "video" ];
    };

    # the recorder used to run as root, so take over anything it left behind
    systemd.tmpfiles.rules = [ "d ${fallback} 0755 ${user} users -" "Z ${fallback} - ${user} users -" ];

    systemd.user.services.record = {
      description = "continuous segmented webcam recording";
      wantedBy = [ "default.target" ];
      after = [ "pipewire.service" "pipewire-pulse.socket" ];
      wants = [ "pipewire-pulse.socket" ];
      unitConfig.ConditionUser = user;

      environment = {
        EXT_DATA_DIR = config.machine.ext_data_dir;
        DATA_MOUNT_UNIT = dataMount;
        RECORD_FALLBACK = fallback;
        RECORD_FPS = "24";
      };

      serviceConfig = {
        ExecStart = lib.getExe record;
        # retry forever until the camera is present
        Restart = "always";
        RestartSec = 10;
        Nice = 5;
      };
      startLimitIntervalSec = 0;
    };

    # user units can't follow the system mount, so move the recorder onto the
    # array when it mounts and back to the fallback before it unmounts.
    systemd.services.record-follow-data = mountGate.gate config.machine.ext_data_dir // {
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = [
          "${pkgs.coreutils}/bin/install -d -o ${user} -g users ${out}"
          "${pkgs.coreutils}/bin/chown -R ${user}:users ${out}"
        ];
        ExecStart = restartRecord;
        ExecStop = restartRecord;
      };
    };
  };
}
