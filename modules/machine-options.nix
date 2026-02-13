{ config, lib, pkgs, ... }: rec {
  options = {
    machine.is_desktop = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    machine.name = lib.mkOption {
      type = lib.types.str;
      default = "mahmooz1";
    };
    machine.user = lib.mkOption {
      type = lib.types.str;
      default = "mahmooz";
    };
    machine.static_ip = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.100";
    };
    machine.enable_nvidia = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    machine.is_home_server = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    machine.is_linux = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    machine.is_darwin = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    machine.is_vm = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "is this a VM build?";
    };
    machine.voldir = lib.mkOption {
      type = lib.types.str;
      default = "/Volumes/main";
    };
    machine.datadir = lib.mkOption {
      type = lib.types.str;
      default = "/data";
    };
    machine.can_compile = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    machine.llama-cpp = {
      pkg = lib.mkOption {
        type = lib.types.package;
        default = pkgs.llama-cpp;
      };
    };

    machine.podman = {
      pkg = lib.mkOption {
        type = lib.types.package;
        default = pkgs.podman;
      };
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
