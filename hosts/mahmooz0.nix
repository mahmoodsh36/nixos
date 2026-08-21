# this is for macos
{ config, pkgs, lib, inputs, self, myutils, pkgs-pinned, ... }:

let
  constants = import ../lib/constants.nix;
  # in the persistent workdir, linux-builder-start wipes $TMPDIR on every launch
  builder_qmp = "/var/lib/linux-builder/qmp.sock";
  taps = {
    "homebrew/homebrew-core" = inputs.homebrew-core;
    "homebrew/homebrew-cask" = inputs.homebrew-cask;
    # we need to add "homebrew-" prefix
  };
in
{
  config = {
    # required for nix-darwin to work
    system.stateVersion = 1;
    system.primaryUser = "${config.machine.user}";

    environment.systemPackages = (with pkgs; [
      macpm # asitop
      # utm
      keycastr
    ]) ++ [
      # puts the stock `vllm` CLI on PATH. the vllm-metal plugin has no
      # command of its own, it hooks in via vllm's platform_plugins entry
      # point. drags in torch, so it is a big closure.
      self.packages.${pkgs.stdenv.hostPlatform.system}.vllm-metal-env
      # `mineru` pdf extraction cli
      self.packages.${pkgs.stdenv.hostPlatform.system}.mineru-env
      self.packages.${pkgs.stdenv.hostPlatform.system}.llama-cpp
      self.packages.${pkgs.stdenv.hostPlatform.system}.llama-convert-hf-to-gguf
      # venus launchers: `run-mahmooz1-vm` (cocoa window) and
      # `run-mahmooz1-vm-console` (serial console).
      self.packages.${pkgs.stdenv.hostPlatform.system}.vm
      self.packages.${pkgs.stdenv.hostPlatform.system}.vm-headless
    ];

    # our headscale tailnet uses a custom magicdns suffix (tailnet.${constants.mydomain})
    # instead of the default *.ts.net, macos doesn't route dns queries for it to
    # tailscale's resolver on its own, so register it explicitly, same mechanism
    # tailscale itself uses for *.ts.net
    environment.etc."resolver/tailnet.${constants.mydomain}".text = ''
      nameserver 100.100.100.100
    '';

    # necessary temporary fix
    ids.gids.nixbld = 350;

    machine.podman.pkg = pkgs-pinned.podman;

    environment.variables.HOMEBREW_NO_ANALYTICS = "1";

    users.users."${config.machine.user}" = {
      name = config.machine.user;
      # see the reference docs for more on user config:
      # https://nix-darwin.github.io/nix-darwin/manual/#opt-users.users
    };

    nix-homebrew = {
      taps = taps;
      # install homebrew under the default prefix
      enable = true;
      # apple silicon only: also install homebrew under the default intel prefix for rosetta 2
      enableRosetta = true;
      # user owning the homebrew prefix
      user = "${config.machine.user}";
      # with mutabletaps disabled, taps can no longer be added imperatively with `brew tap`.
      mutableTaps = false;
    };

    homebrew = {
      enable = true;
      # align homebrew taps config with nix-homebrew
      taps = builtins.attrNames config.nix-homebrew.taps;
      casks = [
        "fuse-t"
        "raycast"
        "karabiner-elements"
        "xnviewmp"
        "openmtp"
        "jordanbaird-ice"
        "whatsapp"
        # "whisky"
        "obs"
        "transmission"
        "comfyui"
        "tor-browser"
        "lm-studio"
        # "audacious"
        # "deadbeef"
        # "petrichor"
        "swama"
        "shortcat"
        "keka"
        # "lulu"
        "google-chrome"
        "sabnzbd"
        "wacom-tablet"
        "zoom"
        "slack"
        # "rnote"
        "discord"
        "spotify"
      ];
      brews = [
        "mole"
      ];
      global = {
        autoUpdate = false;
      };
      onActivation.autoUpdate = true;
      onActivation.upgrade = true;
      onActivation.cleanup = "uninstall";
      masApps = {
        "XCode" = 497799835;
        # "Lockbook" = 1526775001;
        # "Lightroom" = 1451544217;
      };
    };

    system.defaults = {
      dock = {
        autohide = true;
        # magnification = true;
        # mineffect = "scale";
        tilesize = 40;
        autohide-delay = 0.2;
        autohide-time-modifier = 0.1;
        persistent-apps = [
          "/Applications/Nix Apps/Firefox.app"
          "/Applications/Nix Apps/WezTerm.app"
          "/Applications/Nix Apps/Emacs.app"
          "/Applications/Transmission.app"
        ];
      };
      finder = {
        ShowPathbar = true;
        ShowStatusBar = true;
        FXPreferredViewStyle = "clmv"; # column view
      };
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
      };
      loginwindow.GuestEnabled = false;
      NSGlobalDomain = {
        AppleICUForce24HourTime = true;
        AppleInterfaceStyle = "Dark";
        ApplePressAndHoldEnabled = false;
        AppleKeyboardUIMode = 3; # full control/keyboard-navigation
        KeyRepeat = 1; # fastest
        InitialKeyRepeat = 15;
        AppleShowAllExtensions = true;
        "com.apple.trackpad.enableSecondaryClick" = true;
        "com.apple.mouse.tapBehavior" = 1;
      };
      CustomUserPreferences = {
        # settings of plist in /Users/${vars.user}/Library/Preferences/
        "com.apple.finder" = {
          # set home directory as startup window
          NewWindowTargetPath = "file:///Users/${config.machine.user}/";
          NewWindowTarget = "PfHm";
          # set search scope to directory
          # FXDefaultSearchScope = "SCcf";
          # multi-file tab view
          FinderSpawnTab = true;
        };
        "com.apple.desktopservices" = {
          # disable creating .DS_Store files in network an USB volumes
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        # show battery percentage
        "/Users/${config.machine.user}/Library/Preferences/ByHost/com.apple.controlcenter".BatteryShowPercentage = true;
        # privacy
        "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
      };
    };

    # we're using rosetta-builder instead of linux-builder now because it support x86 by default and works with rosetta 2 which is fast
    nix = {
      linux-builder = {
        # https://github.com/nix-darwin/nix-darwin/issues/1192
        enable = true;
        ephemeral = false;
        maxJobs = 4;
        # comment the following 2 expressions out on first run?
        # systems = [ "aarch64-linux" "x86_64-linux" ];
        config = {
          virtualisation = {
            darwin-builder = {
              diskSize = 150 * 1024;
              memorySize = 48 * 1024;
            };
            cores = 8;
            # rosetta.enable = true;
            # nixpkgs hardcodes gic-version=2 for hvf, which qemu 11 rejects outright
            qemu.options = [
              "-machine gic-version=3"
              "-qmp unix:${builder_qmp},server=on,wait=off"
            ];
          };
          # nix doesn't fsync build outputs by default, so a killed qemu leaves fresh store
          # paths truncated to 0 bytes while they stay valid in the db
          nix.settings.fsync-store-paths = true;
          # qemu freezes the guest while the mac sleeps, so its clock falls behind by the
          # sleep duration and tls rejects fresh certs as "not yet valid". the emulated rtc
          # keeps tracking host time, so step the system clock back onto it.
          systemd.services.rtc-resync = {
            startAt = "minutely";
            after = [ "time-set.target" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "/run/current-system/sw/bin/hwclock --hctosys";
            };
          };
        };
      };
      settings.trusted-users = [ "@admin" ];
    };

    # launchd only signals the top-level script, so the qemu grandchild is orphaned on
    # bootout: a darwin-rebuild leaves a stale vm holding port 31022 and the new daemon
    # crash-loops, rebuilding store.img with mkfs.erofs (pegging a core) every 10s.
    launchd.daemons.linux-builder.script = lib.mkBefore ''
      builder_vm='/run/org.nixos.linux-builder/store.img'
      # qemu dies on TERM without shutting the guest down, see fsync-store-paths above
      if /usr/bin/pgrep -f "$builder_vm" > /dev/null; then
        { printf '{"execute":"qmp_capabilities"}{"execute":"system_powerdown"}'; sleep 2; } \
          | /usr/bin/nc -U '${builder_qmp}' > /dev/null 2>&1 || true
        for _ in $(/usr/bin/seq 120); do
          /usr/bin/pgrep -f "$builder_vm" > /dev/null || break
          sleep 0.25
        done
      fi
      for sig in TERM KILL; do
        /usr/bin/pkill -$sig -f "$builder_vm" || break
        for _ in $(/usr/bin/seq 40); do
          /usr/bin/pgrep -f "$builder_vm" > /dev/null || break 2
          sleep 0.25
        done
      done
      rm -f '${builder_qmp}'
    '';

    # nix-rosetta-builder = {
    #   enable = true;
    #   onDemand = true;
    #   cores = 8;
    #   memory = "32GiB";
    #   permitNonRootSshAccess = true;
    #   diskSize = "150GiB";
    #   onDemandLingerMinutes = 30;
    # };

    # https://github.com/nix-darwin/nix-darwin/issues/1041
    # services.karabiner-elements = {
    #   enable = true;
    #   package = pkgs.karabiner-elements.overrideAttrs (old: {
    #     version = "14.13.0";
    #
    #     src = pkgs.fetchurl {
    #       inherit (old.src) url;
    #       hash = "sha256-gmJwoht/Tfm5qMecmq1N6PSAIfWOqsvuHU8VDJY8bLw=";
    #     };
    #
    #     dontFixup = true;
    #   });
    # };
  };
}
