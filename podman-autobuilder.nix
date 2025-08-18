# A NixOS module to declaratively build container images from Dockerfiles
# and run them as systemd services using Podman.

{ config, lib, pkgs, ... }:

with lib;

let
  # a shortcut to this module's configuration options.
  cfg = config.services.podman-autobuilder;

  # --- Helper Functions for Generating Systemd Services ---

  # generates build and run services for a single container.
  mkContainerServices = name: containerCfg: {
    # the build service. it is a standard boot-time service.
    "podman-autobuild-${name}" = {
      description = "Build Podman image for ${name} from its Dockerfile";
      # this makes it part of the standard system startup transaction.
      wantedBy = [ "multi-user.target" ];
      # the build must happen before the container service tries to start.
      before = [ "podman-container-${name}.service" ];
      serviceConfig = {
        Type = "oneshot";
        # this is important for oneshot services in the boot process.
        RemainAfterExit = true;
        ExecStart = let
          podman = "${pkgs.podman}/bin/podman";
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
      description = "Run Podman container ${name}";
      wantedBy = [ "multi-user.target" ];
      restartIfChanged = true;

      # synchronous dependency:
      # `requires` creates a strong, blocking dependency on the build service.
      # `after` reinforces that this service must only start after the build is done.
      requires = [ "podman-autobuild-${name}.service" ];
      after = [ "podman-autobuild-${name}.service" ];

      serviceConfig = {
        Restart = "always";
        RestartSec = "5s";
        ExecStart = let
          podman = "${pkgs.podman}/bin/podman";
          runArgs = escapeShellArgs containerCfg.runArgs;
        in ''
          ${podman} run --replace --name=${escapeShellArg name} ${runArgs} ${escapeShellArg containerCfg.imageName}
        '';
        ExecStop = let
          podman = "${pkgs.podman}/bin/podman";
        in ''
          ${podman} stop ${escapeShellArg name}
        '';
      };
    };
  };

  # generates a one-shot .service unit for an `exec` command.
  mkExecService = containerName: execName: execCfg: {
    "podman-exec-${containerName}-${execName}" = {
      description = execCfg.description;
      requires = [ "podman-container-${containerName}.service" ];
      after = [ "podman-container-${containerName}.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = let
          podman = "${pkgs.podman}/bin/podman";
          command = escapeShellArgs execCfg.command;
        in ''
          ${podman} exec ${escapeShellArg containerName} ${command}
        '';
      };
    };
  };

in
{
  # --- module options ---
  # this section defines the configuration interface for users in their `configuration.nix`.

  options.services.podman-autobuilder = {
    containers = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          enable = mkEnableOption "this container" // { default = true; };
          imageName = mkOption { type = types.str; description = "The name and tag for the built image (e.g., 'my-app:latest')."; };
          context = mkOption { type = types.path; description = "The build context directory, which contains the Dockerfile."; };
          dockerfile = mkOption { type = types.str; default = "Dockerfile"; description = "The name of the Dockerfile within the context directory."; };
          buildArgs = mkOption { type = types.listOf types.str; default = []; description = "A list of extra arguments to pass to the 'podman build' command."; };
          runArgs = mkOption { type = types.listOf types.str; default = []; description = "A list of arguments to pass to 'podman run'."; };
          execServices = mkOption {
            default = {};
            description = "Defines one-shot systemd services (started manually) to run commands in this container.";
            type = types.attrsOf (types.submodule ({ name, ... }: {
              options = {
                description = mkOption { type = types.str; default = "Run ${name} command in container"; };
                command = mkOption { type = types.listOf types.str; description = "The command and arguments to execute inside the container."; };
              };
            }));
          };
          aliases = mkOption {
            default = {};
            description = "Create host-level command aliases (available system-wide) to run commands inside the container.";
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

  # --- module configuration ---
  # this section generates the nixos system configuration based on the user's options.

  config = mkIf (cfg.containers != {}) (
    let
      # 1. gather all main container services into a single attribute set.
      allContainerServices = lib.foldl lib.recursiveUpdate {} (
        lib.mapAttrsToList (name: containerCfg:
          if containerCfg.enable then (mkContainerServices name containerCfg) else {}
        ) cfg.containers
      );

      # 2. gather all `execServices` from all containers into a single attribute set.
      allExecServices = lib.foldl lib.recursiveUpdate {} (
        lib.mapAttrsToList (name: containerCfg:
          lib.mapAttrs' (execName: execCfg:
            nameValuePair "podman-exec-${name}-${execName}" (mkExecService name execName execCfg)
          ) containerCfg.execServices
        ) cfg.containers
      );

      # 3. create a flat list of script packages from all defined `aliases`.
      allAliasPackages = lib.concatLists (
        lib.mapAttrsToList (containerName: containerCfg:
          lib.mapAttrsToList (aliasName: aliasCfg:
            pkgs.writeShellScriptBin aliasName ''
              #!${pkgs.runtimeShell}
              echo "--> Running '${aliasName}' in container '${containerName}'..."
              INTERACTIVE_FLAG=""
              ${lib.optionalString aliasCfg.interactive ''
                if [ -t 0 ]; then
                  INTERACTIVE_FLAG="-it"
                fi
              ''}
              exec sudo ${pkgs.podman}/bin/podman exec $INTERACTIVE_FLAG ${escapeShellArg containerName} ${lib.escapeShellArgs aliasCfg.command} "$@"
            ''
          ) containerCfg.aliases
        ) cfg.containers
      );

    in
    # --- final configuration attribute set ---
    {
      # merge all generated services into the systemd configuration.
      systemd.services = allContainerServices // allExecServices;

      # add podman and all generated alias scripts to the system's PATH.
      environment.systemPackages = allAliasPackages ++ [ pkgs.podman ];
    }
  );
}