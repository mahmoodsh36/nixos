# A home-manager module to declaratively build container images from Dockerfiles
# and run them as user services using podman. Works on both Linux and macOS.

{ config, lib, pkgs, ... }:

with lib;

let
  # a shortcut to this module's configuration options.
  cfg = config.services.podman-autobuilder;

  # Determine if we're on macOS
  isDarwin = pkgs.stdenv.isDarwin;

  # generates build and run services for a single container on Linux (systemd)
  mkContainerServicesLinux = name: containerCfg: {
    # the build service. it is a standard boot-time service.
    "podman-autobuild-${name}" = {
      Unit = {
        Description = "Build Podman image for ${name} from its Dockerfile";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let
          podman = "${cfg.podmanPackage}/bin/podman";
          buildArgs = escapeShellArgs containerCfg.buildArgs;
        in ''
          ${podman} build \
            ${buildArgs} \
            -t ${escapeShellArg containerCfg.imageName} \
            -f ${toString containerCfg.context}/${containerCfg.dockerfile} \
            ${toString containerCfg.context}
        '';
      };
    };

    # the main service to run the container.
    "podman-container-${name}" = {
      Unit = {
        Description = "Run Podman container ${name}";
        Requires = [ "podman-autobuild-${name}.service" ];
        After = [ "podman-autobuild-${name}.service" ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
      Service = {
        Restart = "always";
        RestartSec = "5s";

        ExecStart = let
          podman = "${cfg.podmanPackage}/bin/podman";
          runArgs = escapeShellArgs containerCfg.runArgs; # options like --network, -p
          command = escapeShellArgs containerCfg.command; # the command inside the container
        in ''
          ${podman} run --replace --name=${escapeShellArg name} ${runArgs} ${escapeShellArg containerCfg.imageName} ${command}
        '';
        ExecStop = let
          podman = "${cfg.podmanPackage}/bin/podman";
        in ''
          ${podman} stop ${escapeShellArg name}
        '';
      };
    };
  };

  # generates build and run services for a single container on macOS (launchd)
  mkContainerServicesDarwin = name: containerCfg: {
    # the build service
    "podman-autobuild-${name}" = {
      enable = true;
      config = {
        Label = "podman.autobuild.${name}";
        ProgramArguments = let
          podman = "${cfg.podmanPackage}/bin/podman";
          buildArgs = containerCfg.buildArgs;
        in
          [ podman "build" ]
          ++ buildArgs
          ++ [ "-t" containerCfg.imageName
               "-f" "${toString containerCfg.context}/${containerCfg.dockerfile}"
               (toString containerCfg.context)
             ];
        RunAtLoad = true;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/podman-autobuild-${name}.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/podman-autobuild-${name}.log";
      };
    };

    # the main service to run the container
    "podman-container-${name}" = {
      enable = true;
      config = {
        Label = "podman.container.${name}";
        ProgramArguments = let
          podman = "${cfg.podmanPackage}/bin/podman";
          runArgs = containerCfg.runArgs;
          command = containerCfg.command;
        in
          [ podman "run" "--replace" "--name=${name}" ]
          ++ runArgs
          ++ [ containerCfg.imageName ]
          ++ command;
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
          Crashed = true;
        };
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/podman-container-${name}.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/podman-container-${name}.log";
      };
    };
  };

  # generates a one-shot service unit for an `exec` command on Linux.
  mkExecServiceLinux = containerName: execName: execCfg: {
    "podman-exec-${containerName}-${execName}" = {
      Unit = {
        Description = execCfg.description;
        Requires = [ "podman-container-${containerName}.service" ];
        After = [ "podman-container-${containerName}.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = let
          podman = "${cfg.podmanPackage}/bin/podman";
          command = escapeShellArgs execCfg.command;
        in ''
          ${podman} exec ${escapeShellArg containerName} ${command}
        '';
      };
    };
  };

  # generates a one-shot service unit for an `exec` command on macOS.
  mkExecServiceDarwin = containerName: execName: execCfg: {
    "podman-exec-${containerName}-${execName}" = {
      enable = true;
      config = {
        Label = "podman.exec.${containerName}.${execName}";
        ProgramArguments = let
          podman = "${cfg.podmanPackage}/bin/podman";
        in
          [ podman "exec" containerName ] ++ execCfg.command;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/podman-exec-${containerName}-${execName}.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/podman-exec-${containerName}-${execName}.log";
      };
    };
  };

in
{
  # this section defines the configuration interface for users in their home-manager configuration.

  options.services.podman-autobuilder = {
    enable = mkEnableOption "podman-autobuilder service";

    podmanPackage = mkOption {
      type = types.package;
      default = pkgs.podman;
      description = "The podman package to use.";
    };

    containers = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          enable = mkEnableOption "this container" // { default = true; };
          imageName = mkOption { type = types.str; description = "The name and tag for the built image (e.g., 'my-app:latest')."; };
          context = mkOption { type = types.path; description = "The build context directory, which contains the Dockerfile."; };
          dockerfile = mkOption { type = types.str; default = "Dockerfile"; description = "The name of the Dockerfile within the context directory."; };
          buildArgs = mkOption { type = types.listOf types.str; default = []; description = "A list of extra arguments to pass to the 'podman build' command."; };

          runArgs = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "A list of OPTIONS to pass to 'podman run' (e.g., --network, -p, -v).";
            example = [ "-p" "8080:80" "--network=host" ];
          };
          command = mkOption {
            type = types.listOf types.str;
            default = []; # Defaults to an empty list, which uses the Dockerfile's CMD
            description = "The command to run inside the container, overriding the Dockerfile's CMD.";
            example = [ "sleep" "infinity" ];
          };

          execServices = mkOption {
            default = {};
            description = "Defines one-shot services (started manually) to run commands in this container.";
            type = types.attrsOf (types.submodule ({ name, ... }: {
              options = {
                description = mkOption { type = types.str; default = "Run ${name} command in container"; };
                command = mkOption { type = types.listOf types.str; description = "The command and arguments to execute inside the container."; };
              };
            }));
          };
          aliases = mkOption {
            default = {};
            description = "Create user-level command aliases to run commands inside the container.";
            type = types.attrsOf (types.submodule ({ name, ... }: {
              options = {
                command = mkOption { type = types.listOf types.str; description = "The command and arguments to execute inside the container."; };
                interactive = mkOption { type = types.bool; default = false; description = "Whether to run the command in interactive mode (with a TTY). Use for shells."; };
              };
            }));
          };
        };
      }));
      default = {};
    };
  };

  # this section generates the home-manager configuration based on the user's options.

  config = mkIf (cfg.enable && cfg.containers != {}) (
    let
      # Helper functions to choose between Linux and Darwin implementations
      mkContainerServices = if isDarwin then mkContainerServicesDarwin else mkContainerServicesLinux;
      mkExecService = if isDarwin then mkExecServiceDarwin else mkExecServiceLinux;

      # 1. gather all main container services into a single attribute set.
      allContainerServices = lib.foldl lib.recursiveUpdate {} (
        lib.mapAttrsToList (name: containerCfg:
          if containerCfg.enable then (mkContainerServices name containerCfg) else {}
        ) cfg.containers
      );

      # 2. gather all `execServices` from all containers into a single attribute set.
      allExecServices = lib.foldl lib.recursiveUpdate {} (
        lib.mapAttrsToList (name: containerCfg:
          lib.foldl lib.recursiveUpdate {} (
            lib.mapAttrsToList (execName: execCfg:
              mkExecService name execName execCfg
            ) containerCfg.execServices
          )
        ) cfg.containers
      );

      # 3. create a flat list of script packages from all defined `aliases`.
      allAliasPackages = lib.concatLists (
        lib.mapAttrsToList (containerName: containerCfg:
          lib.mapAttrsToList (aliasName: aliasCfg:
            pkgs.writeShellScriptBin aliasName ''
              #!${pkgs.runtimeShell}
              set -euo pipefail

              # Auto-build image if it doesn't exist
              if ! ${cfg.podmanPackage}/bin/podman image exists ${escapeShellArg containerCfg.imageName}; then
                echo "Building ${containerName} container image..."
                ${cfg.podmanPackage}/bin/podman build \
                  ${lib.concatStringsSep " " (map escapeShellArg containerCfg.buildArgs)} \
                  -t ${escapeShellArg containerCfg.imageName} \
                  -f ${toString containerCfg.context}/${containerCfg.dockerfile} \
                  ${toString containerCfg.context} || {
                  echo "Failed to build container image. Please check the Dockerfile."
                  exit 1
                }
              fi

              # Auto-run container if it's not running
              if ! ${cfg.podmanPackage}/bin/podman ps --format "table {{.Names}}" | grep -q "^${escapeShellArg containerName}$"; then
                echo "Container '${containerName}' not running. Starting it..."
                # Remove existing container if it exists but is stopped
                ${cfg.podmanPackage}/bin/podman rm -f ${escapeShellArg containerName} 2>/dev/null || true
                # Run new container
                ${cfg.podmanPackage}/bin/podman run -d \
                  --name ${escapeShellArg containerName} \
                  ${lib.concatStringsSep " " (map escapeShellArg containerCfg.runArgs)} \
                  ${escapeShellArg containerCfg.imageName} \
                  ${lib.concatStringsSep " " (map escapeShellArg containerCfg.command)} || {
                  echo "Failed to start container. Please check container logs."
                  exit 1
                }
                # Wait for container to be ready
                sleep 3
              fi

              # Execute command in the container
              INTERACTIVE_FLAG=""
              ${lib.optionalString aliasCfg.interactive ''
                if [ -t 0 ]; then
                  INTERACTIVE_FLAG="-it"
                fi
              ''}
              exec ${cfg.podmanPackage}/bin/podman exec $INTERACTIVE_FLAG ${escapeShellArg containerName} ${lib.escapeShellArgs aliasCfg.command} "$@"
            ''
          ) containerCfg.aliases
        ) cfg.containers
      );

    in
    {
      # merge all generated services into the appropriate service manager
    } // (if isDarwin then {
      # On macOS, use launchd agents
      launchd.agents = allContainerServices // allExecServices;
    } else {
      # On Linux, use systemd user services
      systemd.user.services = allContainerServices // allExecServices;
    }) // {
      # add podman and all generated alias scripts to the user's PATH.
      home.packages = allAliasPackages ++ [ cfg.podmanPackage ];
    }
  );
}
