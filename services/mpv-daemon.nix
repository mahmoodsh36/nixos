{ config, pkgs, lib, system, inputs, ... }:

let
  isDarwin = builtins.match ".*-darwin" system != null;
  isLinux = builtins.match ".*-linux" system != null;
  mpvHistoryDaemonPkg = inputs.mpv-history-daemon.packages.${pkgs.system}.default;
  sockets_dir = "/tmp/mpv_sockets/";
in
{
  options.mpv-daemon = {
    enable = lib.mkEnableOption "MPV History Daemon service";
  };

  config = {} // (if isDarwin then {
    # macOS launchd service
    launchd.agents.mpv-history-daemon = lib.mkIf config.mpv-daemon.enable {
      command = pkgs.writeShellScript "start-mpv-history-daemon.sh" ''
        #!${pkgs.stdenv.shell}
        # ensure directories exist
        mkdir -p ${sockets_dir}
        mkdir -p ${config.machine.voldir}/data/mpv_data

        # start the daemon
        exec ${mpvHistoryDaemonPkg}/bin/mpv-history-daemon daemon \
          --log-file ${config.machine.voldir}/data/mpv_data/my_log_file \
          --write-period 30 \
          --scan-time 1 \
          ${sockets_dir} \
          ${config.machine.voldir}/data/mpv_data
      '';

      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "${config.machine.voldir}/data/mpv_data/daemon.log";
        StandardErrorPath = "${config.machine.voldir}/data/mpv_data/daemon_error.log";
        UserName = config.machine.user;
        GroupName = "staff";
      };
    };
  } else {}) // (if isLinux then {
    # Linux systemd service
    systemd.user.services.mpv-history-daemon = lib.mkIf config.mpv-daemon.enable {
      enable = true;
      description = "MPV History Daemon";
      wantedBy = [ "default.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = ''
          ${mpvHistoryDaemonPkg}/bin/mpv-history-daemon daemon \
            --log-file ${config.machine.voldir}/data/mpv_data/my_log_file \
            --write-period 30 \
            --scan-time 1 \
            ${sockets_dir} \
            ${config.machine.voldir}/data/mpv_data
        '';
        Restart = "on-failure";
        RestartSec = 5;
        Type = "simple";
      };

      # Ensure the data directories exist
      preStart = ''
        mkdir -p ${sockets_dir}
        mkdir -p ${config.machine.voldir}/data/mpv_data
      '';
    };
  } else {});
}