{ config, pkgs, lib, inputs, ... }:

let
  mcp_config = inputs.mcp-servers-nix.lib.mkConfig pkgs {
    # format = "json";
    flavor = "zed";
    programs = {
      fetch = {
        enable = true;
      };
      time = {
        enable = true;
        args = [ "--local-timezone" "Asia/Jerusalem" ];
      };
      git = {
        enable = true;
      };
      sequential-thinking = {
        enable = true;
      };
      filesystem = {
        enable = false;
      };
      playwright = {
        enable = true;
      };
      everything = {
        enable = true;
        url = "http://localhost:3001/sse";
      };
    };
    settings = {
      # servers = {
      #   yasunori = {
      #     command = lib.getExe pkgs.yasunori-mcp;
      #   };
      #   astro = {
      #     url = "http://localhost:4321/__mcp/sse";
      #   };
      # };
    };
  };
in
{
  options = with lib; with types; {
    mcp_config = mkOption {
      type = attrs;
    };
  };

  config = lib.mkIf config.machine.is_desktop {
    xdg.configFile."Code/User/cline_mcp_settings.json" = {
      source = mcp_config;
    };
    mcp_config = mcp_config;
  };
}