{
  description = "nixos flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      # url = "github:nix-community/home-manager/release-25.05";
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lem = {
      # url = "github:lem-project/lem";
      # url = "github:mahmoodsh36/lem";
      url = "github:lem-project/lem/38bae05a03bd6e6394819873fe5414b38da4753d";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pkgs-pinned.url = "github:NixOS/nixpkgs/17f6bd177404d6d43017595c5264756764444ab8";
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
      url = "github:ggml-org/llama.cpp";
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

    # for python
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "pkgs-pinned";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "pkgs-pinned";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "pkgs-pinned";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
  };

  outputs = {
    self, nixpkgs, home-manager, plasma-manager, ...
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
      # to fix another error when generating iso
      boot.kernel.sysctl."vm.overcommit_memory" = nixpkgs.lib.mkForce "1";
      # isoImage.contents = [ { source = /home/mahmooz/work/scripts; target = "/home/mahmooz/scripts"; } ];
    };
    uvpkgs = import inputs.pkgs-pinned {
      inherit system;
      config.allowUnfree = true;
      config.cudaSupport = true;
    };
    uvpython = uvpkgs.python312;
    mlvenv = (import ./uv_python.nix {
      pkgs = uvpkgs;
      pyproject-nix = inputs.pyproject-nix;
      uv2nix = inputs.uv2nix;
      pyproject-build-systems = inputs.pyproject-build-systems;
      python = uvpython;
    });
    mkSystem = extraModules:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          inherit system;
        };
        modules = [
          ./machine.nix
          ./machine-config.nix
          home-manager.nixosModules.home-manager
          inputs.arion.nixosModules.arion
          inputs.declarative-jellyfin.nixosModules.default
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.mahmooz = import ./home.nix;
            home-manager.backupFileExtension = "hmbkup";
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.sharedModules = [
              plasma-manager.homeManagerModules.plasma-manager
            ];
          }
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
        ./network-local.nix
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
            environment.systemPackages = pkgs.lib.mkIf (builtins.pathExists ./uv.lock ) [
              (uvpkgs.writeShellScriptBin "mlpython" ''
                export LD_LIBRARY_PATH=/run/opengl-driver/lib
                export TRITON_LIBCUDA_PATH=/run/opengl-driver/lib
                export TRITON_PTXAS_PATH="${uvpkgs.cudatoolkit}/bin/ptxas"
                exec ${mlvenv}/bin/python "$@"
              '')
            ];
          };
        })
        ./network-local.nix
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
        ./network-local.nix
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
    devShells."${system}" = {
      ml = uvpkgs.mkShell {
        packages = [
          mlvenv
        ];
        env = {
          CUDA_PATH = "${uvpkgs.cudatoolkit}";
        };
        shellHook = ''
          export LD_LIBRARY_PATH=/run/opengl-driver/lib
          export TRITON_LIBCUDA_PATH=/run/opengl-driver/lib
          export TRITON_PTXAS_PATH="${uvpkgs.cudatoolkit}/bin/ptxas"
        '';
      };
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
  };
}