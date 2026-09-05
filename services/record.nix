{ config, pkgs, lib, self, ... }:

let
  record = self.packages.${pkgs.system}.record;
in
{
  options.services.record.enable =
    lib.mkEnableOption "continuous segmented webcam recording";

  config = lib.mkIf config.services.record.enable {
    environment.systemPackages = [ record ];

    systemd.services.record = {
      description = "continuous segmented webcam recording";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];

      environment = {
        DATA_DIR = config.machine.datadir;
        RECORD_FALLBACK = "${config.machine.voldir}/wc";
        RECORD_FPS = "24";
      };

      serviceConfig = {
        ExecStart = lib.getExe record;
        # retry forever until the array is unlocked and the camera is present
        Restart = "always";
        RestartSec = 10;
        StartLimitIntervalSec = 0;
        Nice = 5;
      };
    };
  };
}
