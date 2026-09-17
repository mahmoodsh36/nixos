{ config, pkgs, lib, inputs, myutils, pkgs-pinned, ... }:

let
  work_dir = "${config.machine.voldir}/work";
  scripts_dir = "${config.machine.voldir}/work/scripts";
in
{
  config = lib.mkIf (config.machine.is_linux && config.machine.is_desktop) {
    boot = {
      kernelParams = [
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "usbcore.autosuspend=-1" # or 120 to wait two minutes, etc
      ];
    };

    # better safe than sorry (for having to deal with firmware/driver issues)..?
    hardware.enableAllHardware = (!config.machine.is_vm) && (!config.machine.low_resources);
    hardware.enableAllFirmware = (!config.machine.is_vm) && (!config.machine.low_resources);
    hardware.usb-modeswitch.enable = !config.machine.low_resources;
    services.hardware.bolt.enable = !config.machine.low_resources;

    # for firmware updates
    services.fwupd.enable = (!config.machine.is_vm) && (!config.machine.low_resources);

    # enable sound and bluetooth
    # services.blueman.enable = true;
    hardware.bluetooth = {
      enable = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
        Policy = {
          AutoEnable = "true";
        };
      };
      powerOnBoot = true;
    };
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # graphical stuff
    services.libinput = {
      enable = true;
      touchpad = {
        disableWhileTyping = true;
        tappingDragLock = false;
        accelSpeed = "0.9";
        naturalScrolling = false;
        additionalOptions = ''
          Option "PalmDetection" "on"
        '';
      };
    };
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      # systemd-managed session, otherwise graphical-session.target never
      # activates and xremap never starts
      withUWSM = true;
    };
    programs.uwsm.waylandCompositors.hyprland = {
      prettyName = "Hyprland";
      comment = "hyprland managed by uwsm";
      binPath = "/run/current-system/sw/bin/Hyprland";
    };
    xdg.portal = {
      # xdgOpenUsePortal = true; # this seems to override my .desktop definitions in home-manager?
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
        # pkgs.xdg-desktop-portal-hyprland
        pkgs.xdg-desktop-portal-wlr
      ];
      config.hyprland = {
        default = [
          "wlr"
          "gtk"
        ];
      };
    };
    services.greetd = {
      enable = true;
      settings = {
        initial_session = {
          command = "${lib.getExe pkgs.uwsm} start ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions/hyprland-uwsm.desktop";
          user = config.machine.user;
        };
        default_session = {
          command = "${lib.getExe pkgs.tuigreet} --time --remember --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions --cmd '${lib.getExe pkgs.uwsm} start ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions/hyprland-uwsm.desktop'";
          user = "greeter";
        };
      };
    };
    programs.niri.enable = true;

    # tty configs
    security.audit.enable = !config.machine.low_resources;
    security.auditd.enable = !config.machine.low_resources;

    # ask for password in terminal instead of x11-ash-askpass
    programs.ssh.askPassword = "";

    services.printing.enable = !config.machine.low_resources; # CUPS

    # dont hibernate when lid is closed
    services.logind.lidSwitch = "ignore";

    # dictionaries
    services.dictd.enable = !config.machine.low_resources;
    services.dictd.DBs = with pkgs.dictdDBs; [ wiktionary wordnet ];

    documentation.dev.enable = !config.machine.low_resources;

    environment.systemPackages = with pkgs; [
      # overwrite notify-send to not let anything handle notifications
      (pkgs.writeShellScriptBin "notify-send" ''
        echo $@ > /tmp/notif
      '')

      pavucontrol
      alsa-utils
      playerctl # media control

      # wayland
      wl-clipboard
      usbutils
      pciutils
      grim slurp # for screenshots
      brightnessctl
      swww # wallpaper setter
    ] ++ pkgs.lib.optionals (!config.machine.low_resources) [
      vulkan-tools mesa-demos
      ocrmypdf poppler-utils
      pulsemixer # tui for pulseaudio control
      gptfdisk parted
      btrfs-progs
      wf-recorder
      wl-screenrec
      libinput
      bluez-tools blueman
      material-design-icons
      cryptsetup
    ];

    # without this okular is blurry
    environment.sessionVariables.QT_QPA_PLATFORM = "wayland";

    # read by configs that need vm-specific behavior
    environment.sessionVariables.IS_VM = lib.mkIf config.machine.is_vm "1";

    services.udev.extraRules = ''
      SUBSYSTEM=="block", ENV{ID_FS_UUID}=="777ddbd7-9692-45fb-977e-0d6678a4a213", RUN+="${pkgs.coreutils}/bin/mkdir -p /home/mahmooz/mnt" RUN+="${pkgs.systemd}/bin/systemd-mount $env{DEVNAME} /home/mahmooz/mnt/", RUN+="${lib.getExe pkgs.logger} --tag my-manual-usb-mount udev rule success, drive: %k with uuid $env{ID_FS_UUID}"
      SUBSYSTEM=="block", ENV{ID_FS_UUID}=="be5af23f-da6d-42ee-a346-5ad3af1a299a", RUN+="${pkgs.coreutils}/bin/mkdir -p /home/mahmooz/mnt2" RUN+="${pkgs.systemd}/bin/systemd-mount $env{DEVNAME} /home/mahmooz/mnt2", RUN+="${lib.getExe pkgs.logger} --tag my-manual-usb-mount udev rule success, drive: %k with uuid $env{ID_FS_UUID}"
    '';

    powerManagement = {
      enable = true;
      powertop.enable = !config.machine.low_resources;
      cpuFreqGovernor = "ondemand";
    };

    # helps finding the package that contains a specific file
    programs.nix-index = {
      enable = !config.machine.low_resources;
      enableZshIntegration = true;
      enableBashIntegration = true;
    };
    programs.command-not-found.enable = false; # needed for nix-index

    programs.dconf.enable = true;
  };
}