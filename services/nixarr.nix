{ config, pkgs, lib, inputs, ... }:

let
  cfg = config.services.nixarr;
  mountGate = import ../lib/mount-gate.nix { inherit lib pkgs; };

  # the volume the whole suite lives on, state and media both go to
  # ${volume}/arr. this is normally /data, which is noauto + nofail and has to
  # be unlocked and mounted by hand (see the unlock-data/lock-data scripts).
  volume = config.machine.ext_data_dir;
  volumeUnit = mountGate.mountUnit volume;
  arrRoot = "${volume}/arr";

  # every unit that owns state or writes media on the volume
  gated = [
    "jellyfin"
    "seerr"
    "sonarr"
    "radarr"
    "lidarr"
    "prowlarr"
    "bazarr"
    "transmission"
  ];
in
{
  imports = [ inputs.nixarr.nixosModules.default ];

  options.services.nixarr.enable =
    lib.mkEnableOption "the nixarr media suite, gated on the ${volume} volume";

  config = lib.mkMerge [
    {
      # home servers with a data volume get the suite, hosts without one (no
      # mount for machine.ext_data_dir) are left alone
      services.nixarr.enable = lib.mkDefault (
        config.machine.is_linux
        && config.machine.is_home_server
        && builtins.hasAttr volume config.fileSystems
      );
    }

    (lib.mkIf cfg.enable {
      nixarr = {
        enable = true;
        mediaDir = "${arrRoot}/media";
        stateDir = "${arrRoot}/.state/nixarr";
        # so the desktop user can poke at the library
        mediaUsers = [ config.machine.user ];

        jellyfin.enable = true;
        seerr.enable = true;
        sonarr.enable = true;
        radarr.enable = true;
        lidarr.enable = true;
        prowlarr.enable = true;
        bazarr.enable = true;
        # not VPN-confined: nixarr.transmission.vpn.enable needs
        # nixarr.vpn.enable + nixarr.vpn.wgConf on the volume
        transmission.enable = true;
      };

      # nixarr's tmpfiles rules run at boot, when ${volume} is normally not
      # mounted, so on first setup they land in the empty mountpoint on the
      # root fs and are then shadowed by the real volume. re-run them once the
      # volume is actually there so the tree exists on it.
      systemd.services = lib.genAttrs gated (name: mountGate.gate volume) // {
        nixarr-dirs = mountGate.gate volume // {
          description = "Create nixarr directories on ${volume}";
          before = map (name: "${name}.service") gated;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${lib.getExe' config.systemd.package "systemd-tmpfiles"} --create --prefix=${arrRoot}";
          };
        };
      };
    })
  ];
}