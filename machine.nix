{ config, lib, ... }: rec {
  options = {
    machine.is_desktop = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    machine.name = lib.mkOption {
      type = lib.types.str;
      default = "mahmooz1";
    };
    machine.static_ip = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.100";
    };
    machine.remote_tunnel_port = lib.mkOption {
      type = lib.types.str;
      default = "5001";
    };
    machine.enable_nvidia = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = {
    # this doesnt work
    # machine.static_ip = lib.mkDefault
    #   (if config.machine.name == "mahmooz1" then "192.168.1.1"
    #    else if config.machine.name == "mahmooz2" then "192.168.1.2"
    #    else "192.168.1.100");
  };
}