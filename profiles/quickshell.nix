{ lib, config, inputs, ... }:

# the shell and its deps come from the quickshell repo's module, this only sets the machine bits
{
  imports = [ inputs.quickshell-config.nixosModules.default ];

  config = lib.mkIf (config.machine.is_linux && config.machine.is_desktop) {
    mahmooz.quickshell = {
      enable = true;
      liveDir = "${config.machine.voldir}/work/quickshell";
      env.NOTES_DIR = "${config.machine.voldir}/brain/notes";
    };
  };
}
