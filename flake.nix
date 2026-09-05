{
  description = "nixos flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    pkgs-pinned.url = "github:NixOS/nixpkgs/nixos-unstable";
    pkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-venus = {
      url = "github:mahmoodsh36/nix-venus";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lem = {
      url = "github:mahmoodsh36/lem-flake";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    mpv-history-daemon = {
      url = "github:mahmoodsh36/mpv-history-daemon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    arion = {
      url = "github:hercules-ci/arion";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cltpt = {
      url = "github:mahmoodsh36/cltpt";
      # inputs.nixpkgs.follows = "pkgs-pinned";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin-emacs = {
      url = "github:nix-giant/nix-darwin-emacs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    trackify = {
      url = "github:mahmoodsheikh36/trackify";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-avf = {
      url = "github:nix-community/nixos-avf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # vllm on apple silicon. built from source (the published wheels bundle
    # prebuilt .so/.metallib artifacts that are gitignored from the repo),
    # see packages/vllm-metal.nix.
    vllm-metal-src = {
      url = "github:vllm-project/vllm-metal";
      flake = false;
    };

    # macos
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    xremap-flake = {
      url = "github:xremap/nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # dotfiles
    otherdots = {
      url = "github:mahmoodsh36/otherdots";
      flake = false;
    };
    nvim = {
      url = "github:mahmoodsh36/nvim";
      flake = false;
    };
    scripts = {
      url = "github:mahmoodsh36/scripts";
      flake = false;
    };
    emacs-d = {
      url = "github:mahmoodsh36/.emacs.d";
      flake = false;
    };
    lem-config = {
      url = "github:mahmoodsh36/lem-config";
      flake = false;
    };

    # for python
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
  };

  outputs = {
    self, nixpkgs, ...
  } @inputs: let
    # define supported systems for NixOS configurations
    supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

    # helper to create packages for a specific system
    mkPkgs = system: import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    isobase = {
      isoImage.squashfsCompression = "gzip -Xcompression-level 1";
      isoImage.forceTextMode = true; # to avoid some issues? https://discourse.nixos.org/t/nix-iso-unable-to-boot-in-uefi-mode-but-other-distros-can/16473/53
      systemd.services.sshd.wantedBy = nixpkgs.lib.mkForce [ "multi-user.target" ];
      networking.wireless.enable = false; # installation-cd-minimal.nix sets that to true
      networking.networkmanager.enable = nixpkgs.lib.mkForce true;
      # to fix another error when generating iso
      boot.kernel.sysctl."vm.overcommit_memory" = nixpkgs.lib.mkForce "1";
      # isoImage.contents = [ { source = /home/mahmooz/work/scripts; target = "/home/mahmooz/scripts"; } ];
    };
    mkSystem = system: extraModules:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs self;
          inherit system;
          myutils = import ./lib/utils.nix { inherit system; };
        };
        modules = [
          ./config.nix
          inputs.home-manager.nixosModules.home-manager
          inputs.arion.nixosModules.arion
        ]
        ++ extraModules;
      };

    forAllSystems = nixpkgs.lib.genAttrs [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

  in {
    nixosConfigurations =
      let
        mkConfigsForSystem = system: let
          machineConfigs = {
            mahmooz1 = [
              ./hardware-configuration.nix # hardware scan results
              ({ lib, ... }: {
                config = {
                  machine.name = "mahmooz1";
                  machine.is_desktop = true;
                  machine.static_ip = "192.168.1.1";
                };
              })
              ./profiles/network-local.nix
              inputs.disko.nixosModules.disko
              ./disko-raid1.nix
            ];
            mahmooz4 = [
              ./hardware-configuration.nix
              ({ lib, ... }: {
                config = {
                  machine.name = "mahmooz4";
                  machine.is_desktop = true;
                  machine.static_ip = "192.168.1.1";
                  machine.is_home_server = true;
                  services.record.enable = true;
                };
              })
              ./profiles/network-local.nix
              inputs.disko.nixosModules.disko
              ./disko-raid1.nix
            ];
            mahmooz5 = [
              # ./hardware-configuration.nix
              inputs.nixos-avf.nixosModules.avf
              ({ lib, ... }: {
                config = {
                  avf.defaultUser = "mahmooz";
                  machine.name = "mahmooz5";
                  machine.is_desktop = false;
                  machine.is_home_server = false;
                  machine.can_compile = false;
                  machine.is_avf = true;
                };
              })
            ];
            mahmooz2 = [
              ./hardware-configuration.nix
              ({ lib, ... }: {
                config = {
                  machine.name = "mahmooz2";
                  machine.is_desktop = true;
                  machine.static_ip = "192.168.1.2";
                  machine.is_home_server = true;
                };
              })
              ./profiles/network-local.nix
            ];
            mahmooz3 = [
              ./hardware-configuration.nix
              {
                config = {
                  machine.name = "mahmooz3";
                  services.trackify.enable = true;
                  networking.firewall.allowedTCPPorts = [ 43594 ];
                  machine.is_desktop = false;
                  machine.can_compile = false;
                  machine.low_resources = true;
                  # needed for virtual machines
                  boot.loader.grub.efiInstallAsRemovable = true;
                  boot.loader.efi.canTouchEfiVariables = nixpkgs.lib.mkForce false;
                  boot.loader.grub.useOSProber = nixpkgs.lib.mkForce false;
                };
              }
            ];
            mahmooz6 = [
              ./hardware-configuration.nix
              ({ lib, ... }: {
                config = {
                  machine.name = "mahmooz6";
                  machine.is_desktop = false;
                  machine.is_home_server = false;
                  machine.can_compile = false;
                  machine.low_resources = true;
                };
              })
            ];
          };
        in {
          "mahmooz1-${system}" = mkSystem system machineConfigs.mahmooz1;
          "mahmooz1-headless-${system}" = mkSystem system (machineConfigs.mahmooz1 ++ [
            ({ lib, ... }: {
              machine.is_desktop = lib.mkForce false;
            })
          ]);
          "mahmooz2-${system}" = mkSystem system machineConfigs.mahmooz2;
          "mahmooz3-${system}" = mkSystem system machineConfigs.mahmooz3;
          "mahmooz4-${system}" = mkSystem system machineConfigs.mahmooz4;
          "mahmooz5-${system}" = mkSystem system machineConfigs.mahmooz5;
          "mahmooz6-${system}" = mkSystem system machineConfigs.mahmooz6;

          "mahmooz1_iso-${system}" = mkSystem system [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            isobase
            {
              config = {
                boot.loader.efi.canTouchEfiVariables = true;
                machine.name = "mahmooz1";
                machine.is_desktop = true;
                machine.static_ip = "192.168.1.1";
                boot.loader.grub.enable = nixpkgs.lib.mkForce true;
                boot.loader.grub.useOSProber = nixpkgs.lib.mkForce true;
              };
            }
            ./profiles/network-local.nix
          ];
          "server_iso-${system}" = mkSystem system [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            isobase
            {
              config = {
                machine.name = "mahmooz3";
                machine.is_desktop = false;
                boot.loader.grub.enable = nixpkgs.lib.mkForce true;
              };
            }
          ];
        };

        allConfigs = nixpkgs.lib.foldl' (acc: system: acc // (mkConfigsForSystem system)) {} supportedSystems;
      in
        allConfigs // {
          # default aliases for x86_64 systems
          mahmooz1 = allConfigs."mahmooz1-x86_64-linux";
          mahmooz2 = allConfigs."mahmooz2-x86_64-linux";
          mahmooz3 = allConfigs."mahmooz3-x86_64-linux";
          mahmooz4 = allConfigs."mahmooz4-x86_64-linux";
          mahmooz5 = allConfigs."mahmooz5-aarch64-linux";
          mahmooz6 = allConfigs."mahmooz6-aarch64-linux";
        };

    devShells = forAllSystems (system: import ./devshells.nix { inherit inputs nixpkgs system; });
    packages = forAllSystems (system: let
      sysPkgs = mkPkgs system;
      isDarwin = nixpkgs.lib.hasInfix "darwin" system;
      linuxSystem = if nixpkgs.lib.hasInfix "aarch64" system then "aarch64-linux" else "x86_64-linux";

      # mahmooz1 extended with the venus-guest profile, so `nix run .#vm`
      # boots the real system under Venus rather than the stub guest.
      # Only on darwin (where the launcher builds) and only if mahmooz1
      # exists for the linux arch.
      venusCustomGuest =
        if (system == "aarch64-darwin"
            && self.nixosConfigurations ? "mahmooz1-${linuxSystem}")
        then self.nixosConfigurations."mahmooz1-${linuxSystem}".extendModules {
          modules = [
            inputs.nix-venus.nixosModules.venus-guest
            ({ config, pkgs, lib, ... }: {
              # hardware-configuration.nix is the x86 bare-metal install
              # config (pins x86_64-linux, Intel modules, disk UUIDs),
              # which is wrong for the VM. venus-guest replaces it.
              disabledModules = [ ./hardware-configuration.nix ];
              machine.is_vm = true;
              venus.guest.enable = true;
              nixpkgs.hostPlatform = linuxSystem;
            })
          ];
        }
        else null;

      venus = inputs.nix-venus.lib.mkVenus {
        inherit nixpkgs;
        hostNixpkgs = inputs.nix-venus.inputs.nixpkgs-venus;
        lib = nixpkgs.lib;
        customGuest = venusCustomGuest;
        hostVoldir =
          if isDarwin && (self ? darwinConfigurations.mahmooz0)
          then self.darwinConfigurations.mahmooz0.config.machine.voldir
          else null;
      };

      venusDarwinPackages = nixpkgs.lib.optionalAttrs (system == "aarch64-darwin") {
        launcher         = venus.launchers.launcher;
        launcher-console = venus.launchers.launcher-console;
        qemu-venus       = venus.qemu-venus;
        qemu-venus-spice = venus.qemu-venus-spice;
        venus-moltenvk   = venus.moltenvk;
        venus-virgl      = venus.virglrenderer;
      };

      venusLinuxPackages = nixpkgs.lib.optionalAttrs (system == "aarch64-linux") {
        venus-guest-image    = venus.guestImage;
        venus-guest-kernel   = venus.guestKernel;
        venus-guest-initrd   = venus.guestInitrd;
        venus-guest-toplevel = venus.guestToplevel;
      };

      basePackages = {
        # continuous segmented webcam recording (used by services/record.nix)
        record = sysPkgs.writeShellApplication {
          name = "record";
          runtimeInputs = with sysPkgs; [ ffmpeg util-linux coreutils ];
          text = builtins.readFile "${inputs.scripts}/record-loop.sh";
        };
        # darwin: mahmooz1 under Venus (`vm` = Cocoa window, `vm-headless`
        # = serial console). Linux: standard NixOS test-vm runner.
        vm =
          if system == "aarch64-darwin"
          then venus.launchers.launcher
          else (self.nixosConfigurations."mahmooz1-${linuxSystem}".extendModules {
            modules = [{ machine.is_vm = true; }];
          }).config.system.build.vm;
        vm-headless =
          if system == "aarch64-darwin"
          then venus.launchers.launcher-console
          else (self.nixosConfigurations."mahmooz1-headless-${linuxSystem}".extendModules {
            modules = [{ machine.is_vm = true; }];
          }).config.system.build.vm;
      };
    in basePackages // venusDarwinPackages // venusLinuxPackages);

    nixosModules = {
      venus-guest = inputs.nix-venus.nixosModules.venus-guest;
    };

    darwinConfigurations = {
      # silicon macs (M1, M2, M3, etc.)
      mahmooz0 =
        let
          system = "aarch64-darwin";
          sysPkgs = mkPkgs system;
        in
          inputs.nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            specialArgs = {
              inherit inputs self;
              system = "aarch64-darwin";
              myutils = import ./lib/utils.nix { inherit system; };
            };
            modules = [
              inputs.mac-app-util.darwinModules.default
              inputs.home-manager.darwinModules.home-manager
              ({ pkgs, ... }: {
                nixpkgs.overlays = [
                  inputs.darwin-emacs.overlays.emacs
                ];
              })
              ({ config, pkgs, lib, ... }: {
                config = {
                  machine.name = "mahmooz0";
                  machine.user = "mahmooz";
                  machine.is_desktop = true;
                  machine.is_linux = false;
                  machine.is_darwin = true;
                  machine.static_ip = "192.168.1.1";
                };
              })
              ./config-darwin.nix
              ./hosts/mahmooz0.nix
              inputs.nix-homebrew.darwinModules.nix-homebrew
            ];
          };
    };
  };
}