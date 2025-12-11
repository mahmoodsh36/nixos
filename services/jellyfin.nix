{ config, pkgs, lib, ... }:

let
  constants = import ../lib/constants.nix;
in
{
  services.declarative-jellyfin = {
    enable = config.machine.is_home_server;
    dataDir = "${config.machine.datadir}/jellyfin";
    system = {
      serverName = "declarative jellyfin";
      # use hardware acceleration for trickplay image generation
      trickplayOptions = lib.mkIf config.machine.enable_nvidia {
        enableHwAcceleration = true;
        enableHwEncoding = true;
      };
      UICulture = "en";
      pluginRepositories = [
        {
          content = {
            Name = "Jellyfin Stable";
            Url = "https://repo.jellyfin.org/files/plugin/manifest.json";
          };
          tag = "RepositoryInfo";
        }
        {
          content = {
            Name = "Intro Skipper";
            Url = "https://intro-skipper.org/manifest.json";
          };
          tag = "RepositoryInfo";
        }
        {
          content = {
            Name = "jellyfin unstable";
            Url = "https://repo.xkrivo.net/jellyfin-dev/manifest.json";
          };
          tag = "RepositoryInfo";
        }
      ];
    };
    users.mahmooz = {
      mutable = false; # overwrite user settings
      permissions.isAdministrator = true;
      password = constants.password;
    };
    libraries = {
      Movies = lib.mkIf (builtins.pathExists "${config.machine.datadir}/movies") {
        enabled = true;
        contentType = "movies";
        pathInfos = [ "${config.machine.datadir}/movies" ];
      };
      Shows = lib.mkIf (builtins.pathExists "${config.machine.datadir}/shows") {
        enabled = true;
        contentType = "tvshows";
        pathInfos = [ "${config.machine.datadir}/shows" ];
      };
      Books = lib.mkIf (builtins.pathExists "${config.machine.datadir}/brain/resources") {
        enabled = true;
        contentType = "books";
        pathInfos = [ "${config.machine.datadir}/resources" ];
      };
      Music = lib.mkIf (builtins.pathExists "${config.machine.datadir}/music" ) {
        enabled = true;
        contentType = "music";
        pathInfos = [ "${config.machine.datadir}/music" ];
      };
    };
    # hardware acceleration
    encoding = lib.mkIf config.machine.enable_nvidia {
      enableHardwareEncoding = true;
      hardwareAccelerationType = "vaapi";
      enableDecodingColorDepth10Hevc = true;
      allowHevcEncoding = true;
      allowAv1Encoding = true;
      hardwareDecodingCodecs = [
        "h264"
        "hevc"
        "mpeg2video"
        "vc1"
        "vp9"
        "av1"
      ];
    };
  };
  # systemd.tmpfiles.rules = [
  #   "d /var/cache/jellyfin 0750 jellyfin jellyfin -"
  #   "d /var/lib/jellyfin 0750 jellyfin jellyfin -"
  # ];
}