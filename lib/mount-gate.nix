#
#   systemd.services.foo = mountGate.gate "/data" // { ... };
#
# gives: foo is stopped the moment /data is unmounted, unplugged or the mount
# unit fails, and is started again when /data is (re)mounted.

{ lib, pkgs }:
let
  nixosUtils = import "${pkgs.path}/nixos/lib/utils.nix" {
    inherit lib pkgs;
    config = { };
  };
  inherit (nixosUtils) escapeSystemdPath;
  inherit (lib) mkForce;
in
rec {
  mountUnit = path: "${escapeSystemdPath (toString path)}.mount";

  # unit attrs that tie a systemd service to `mountPoint` being mounted
  gate = mountPoint: let
    unit = mountUnit mountPoint;
  in {
    # pull the mount in and order after it when the service is started
    requires = [ unit ];
    after = [ unit ];
    # stop the service when the mount goes away, however that happens
    unitConfig.BindsTo = [ unit ];
    # start with the mount instead of at boot
    wantedBy = mkForce [ unit ];
  };
}