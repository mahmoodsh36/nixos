{
  description = "nixos flake";

  inputs = {
    # nixos-unstable branch seems to be the best option (tradeoffs considered) for a native nixos installation.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lem = {
      url = "github:lem-project/lem";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # pkgs-pinned.url = "github:NixOS/nixpkgs/nixos-24.11";
    pkgs-pinned.url = "github:NixOS/nixpkgs/c11863f1e964833214b767f4a369c6e6a7aba141";
    pkgs-master.url = "github:NixOS/nixpkgs/master";
    tgi = {
      url = "github:huggingface/text-generation-inference";
      # inputs.nixpkgs.follows = "nixpkgs"; # makes it fail
    };
    mcp-servers-nix = {
      url = "github:mahmoodsh36/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-comfyui = {
      url = "github:dyscorv/nix-comfyui";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # tgi-nix.url = "github:huggingface/text-generation-inference-nix";
  };

  outputs = {
    self, nixpkgs, home-manager, ...
  } @inputs: let
    system = "x86_64-linux";
    isobase = {
      isoImage.squashfsCompression = "gzip -Xcompression-level 1";
      systemd.services.sshd.wantedBy = nixpkgs.lib.mkForce [ "multi-user.target" ];
      networking.wireless.enable = false; # installation-cd-minimal.nix sets that to true
      # isoImage.contents = [ { source = /home/mahmooz/work/scripts; target = "/home/mahmooz/scripts"; } ];
    };
    mkSystem = extraModules:
      let
        # pkgs = nixpkgs.legacyPackages.${system};
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        # pkgs-master = import inputs.pkgs-master {
        #   system = "x86_64-linux";
        #   config.allowUnfree = true;
        #   # config.cudaSupport = true;
        # };
      in
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
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.mahmooz = import ./home.nix;
              home-manager.backupFileExtension = "hmbkup";
              home-manager.extraSpecialArgs = { inherit inputs; };
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
            boot.loader.efi.canTouchEfiVariables = true;
            machine.name = "mahmooz1";
            machine.is_desktop = true;
            machine.enable_nvidia = false;
            machine.static_ip = "192.168.1.1";
          };
        })
        ./network-local.nix
      ];
      mahmooz2 = mkSystem [
        ./hardware-configuration.nix # hardware scan results
        ({ lib, ... }: {
          config = {
            boot.loader.efi.canTouchEfiVariables = true;
            machine.name = "mahmooz2";
            machine.is_desktop = true;
            machine.enable_nvidia = true;
            machine.static_ip = "192.168.1.2";
          };
        })
        ./network-local.nix
      ];
      # for hetzner etc
      mahmooz3 = mkSystem [
        ./hardware-configuration.nix # hardware scan results
        {
          config = {
            machine.name = "mahmooz3";
            machine.is_desktop = false;
            machine.enable_nvidia = false;
            boot.loader.grub.efiInstallAsRemovable = true;
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
            boot.loader.grub.enable = nixpkgs.lib.mkForce false;
          };
        }
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
  };
}