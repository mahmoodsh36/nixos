{
  description = "nixos flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/08dacfca559e1d7da38f3cf05f1f45ee9bfd213c";
    # nixpkgs.url = "github:NixOS/nixpkgs/ab0f3607a6c7486ea22229b92ed2d355f1482ee0";
    pkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    pkgs-master.url = "github:NixOS/nixpkgs/master";
    home-manager = {
      # url = "github:nix-community/home-manager/release-25.05";
      url = "github:nix-community/home-manager/a3fcc92180c7462082cd849498369591dfb20855";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lem = {
      url = "github:mahmoodsh36/lem";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-servers-nix = {
      url = "github:mahmoodsh36/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    llama-cpp-flake = {
      # url = "github:ggml-org/llama.cpp";
      url = "github:ggml-org/llama.cpp/50f4281a6f5c3a5d68bdeb12f904fa01e0e2ba91";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    arion = {
      url = "github:hercules-ci/arion";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    declarative-jellyfin = {
      url = "github:Sveske-Juice/declarative-jellyfin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stable-diffusion-webui-nix = {
      url = "github:Janrupf/stable-diffusion-webui-nix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cltpt = {
      # url = "github:mahmoodsh36/cltpt/196bde809af1091846f5967578e57911b2a0fae6";
      url = "github:mahmoodsh36/cltpt";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs = {
      url = "github:nix-community/emacs-overlay/7caed42858e94832749eb0087bd6b1c7eab1752b";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wezterm = {
      url = "github:wezterm/wezterm?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    robotnix = {
      url = "github:nix-community/robotnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-on-droid = {
      url = "github:t184256/nix-on-droid";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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
    system = "x86_64-linux";
    pkgs = import nixpkgs {
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
    uvpkgs = import inputs.pkgs {
      inherit system;
      config.allowUnfree = true;
      config.cudaSupport = true;
    };
    uvpython = uvpkgs.python312;
    # mlvenv = (import ./uv_python.nix {
    #   pkgs = uvpkgs;
    #   pyproject-nix = inputs.pyproject-nix;
    #   uv2nix = inputs.uv2nix;
    #   pyproject-build-systems = inputs.pyproject-build-systems;
    #   python = uvpython;
    # });
    mkSystem = extraModules:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          inherit system;
          myutils = import ./lib/utils.nix { };
        };
        modules = [
          ./config.nix
          inputs.home-manager.nixosModules.home-manager
          inputs.arion.nixosModules.arion
          inputs.declarative-jellyfin.nixosModules.default
        ]
        ++ extraModules;
      };
  in {
    nixosConfigurations = {
      mahmooz1 = mkSystem [
        ./hardware-configuration.nix # hardware scan results
        ({ lib, ... }: {
          config = {
            machine.name = "mahmooz1";
            machine.is_desktop = true;
            machine.enable_nvidia = false;
            machine.static_ip = "192.168.1.1";
          };
        })
        ./profiles/network-local.nix
        # disko
        # inputs.disko.nixosModules.disko
        # ./disko-config.nix
        # {
        #   _module.args.disks = [ "/dev/vda" ];
        # }
      ];
      mahmooz2 = mkSystem [
        ./hardware-configuration.nix
        ({ lib, ... }: {
          config = {
            machine.name = "mahmooz2";
            machine.is_desktop = true;
            machine.enable_nvidia = true;
            machine.static_ip = "192.168.1.2";
            machine.is_home_server = true;
            # embed executable for mlpython
            # environment.systemPackages = pkgs.lib.mkIf (builtins.pathExists ./uv.lock ) [
            #   (uvpkgs.writeShellScriptBin "mlpython2" ''
            #     export LD_LIBRARY_PATH=/run/opengl-driver/lib
            #     export TRITON_LIBCUDA_PATH=/run/opengl-driver/lib
            #     export TRITON_PTXAS_PATH="${uvpkgs.cudatoolkit}/bin/ptxas"
            #     exec ${mlvenv}/bin/python "$@"
            #   '')
            # ];
          };
        })
        ./profiles/network-local.nix
      ];
      # for hetzner etc
      mahmooz3 = mkSystem [
        ./hardware-configuration.nix
        {
          config = {
            machine.name = "mahmooz3";
            machine.is_desktop = false;
            machine.enable_nvidia = false;
            # needed for virtual machines
            boot.loader.grub.efiInstallAsRemovable = true;
            boot.loader.efi.canTouchEfiVariables = nixpkgs.lib.mkForce false;
            boot.loader.grub.useOSProber = nixpkgs.lib.mkForce false;

            # this might help prevent system freezing on rebuilds
            nix.settings.max-jobs = 1;
            nix.settings.cores = 1;
            systemd.slices.anti-hungry.sliceConfig = {
              CPUAccounting = true;
              CPUQuota = "50%";
              MemoryAccounting = true; # allow to control with systemd-cgtop
              MemoryHigh = "50%";
              MemoryMax = "75%";
              MemorySwapMax = "50%";
              MemoryZSwapMax = "50%";
            };
            systemd.services.nix-daemon.serviceConfig.Slice = "anti-hungry.slice";
            # kill process using most ram after ram availability drops below
            # a specific threshold.
            services.earlyoom.enable = true;
            services.earlyoom.enableNotifications = true;
          };
        }
      ];
      mahmooz1_iso = mkSystem [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        isobase
        {
          config = {
            boot.loader.efi.canTouchEfiVariables = true;
            machine.name = "mahmooz1";
            machine.is_desktop = true;
            machine.enable_nvidia = false;
            machine.static_ip = "192.168.1.1";
            boot.loader.grub.enable = nixpkgs.lib.mkForce true;
            boot.loader.grub.useOSProber = nixpkgs.lib.mkForce true;
          };
        }
        ./profiles/network-local.nix
      ];
      server_iso = mkSystem [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        isobase
        {
          config = {
            machine.name = "mahmooz3";
            machine.is_desktop = false;
            machine.enable_nvidia = false;
            boot.loader.grub.enable = nixpkgs.lib.mkForce true;
          };
        }
      ];
    };
    nixOnDroidConfigurations.droid = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = import nixpkgs { system = "aarch64-linux"; };
      modules = [ ./hosts/droid.nix ];
    };
    devShells."${system}" = {
      # ml = uvpkgs.mkShell {
      #   packages = [
      #     mlvenv
      #   ];
      #   env = {
      #     CUDA_PATH = "${uvpkgs.cudatoolkit}";
      #     CUDA_HOME = "${uvpkgs.cudatoolkit}";
      #   };
      #   shellHook = ''
      #     export LD_LIBRARY_PATH=/run/opengl-driver/lib
      #     export TRITON_LIBCUDA_PATH=/run/opengl-driver/lib
      #     export TRITON_PTXAS_PATH="${uvpkgs.cudatoolkit}/bin/ptxas"
      #   '';
      # };
      uv = uvpkgs.mkShell {
        packages = with uvpkgs; [
          uvpython
          uv
        ];
        env = {
          UV_PYTHON = uvpython.interpreter;
          UV_PYTHON_DOWNLOADS = "never";
          UV_NO_SYNC = "1";
        };
      };
    };
    robotnixConfigurations = {
      # nix build .#robotnixConfigurations.mylineageos.ota.
      "mylineageos" = inputs.robotnix.lib.robotnixSystem ./android/lineageos.nix;
      "mygrapheneos" = inputs.robotnix.lib.robotnixSystem ./android/grapheneos.nix;
    };
  };
}