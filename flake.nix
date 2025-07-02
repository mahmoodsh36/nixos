{
  description = "nixos flake";

  inputs = {
    # nixos-unstable branch seems to be the best option (tradeoffs considered) for a native nixos installation.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lem = {
      url = "github:lem-project/lem";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # pkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    pkgs-pinned.url = "github:NixOS/nixpkgs/4684fd6b0c01e4b7d99027a34c93c2e09ecafee2";
    # pkgs-master.url = "github:NixOS/nixpkgs/master";
    # pkgs-master.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    tgi = {
      url = "github:huggingface/text-generation-inference";
      # inputs.nixpkgs.follows = "nixpkgs"; # makes it fail
    };
    tei = {
      url = "github:huggingface/text-embeddings-inference";
    };
    mcp-servers-nix = {
      url = "github:mahmoodsh36/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # tgi-nix.url = "github:huggingface/text-generation-inference-nix";
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    llama-cpp-flake = {
      url = "github:ggml-org/llama.cpp";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ikllamacpp = {
      url = "github:ikawrakow/ik_llama.cpp";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ml-pkgs.url = "github:nixvital/ml-pkgs/archive/25.05";
    # ml-pkgs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self, nixpkgs, home-manager, plasma-manager, ...
  } @inputs: let
    system = "x86_64-linux";
    isobase = {
      isoImage.squashfsCompression = "gzip -Xcompression-level 1";
      isoImage.forceTextMode = true; # to avoid some issues? https://discourse.nixos.org/t/nix-iso-unable-to-boot-in-uefi-mode-but-other-distros-can/16473/53
      systemd.services.sshd.wantedBy = nixpkgs.lib.mkForce [ "multi-user.target" ];
      networking.wireless.enable = false; # installation-cd-minimal.nix sets that to true
      # to fix another error when generating iso
      boot.kernel.sysctl."vm.overcommit_memory" = nixpkgs.lib.mkForce "1";
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
        ./hardware-configuration.nix # hardware scan results
        ({ lib, ... }: {
          config = {
            machine.name = "mahmooz2";
            machine.is_desktop = true;
            machine.enable_nvidia = true;
            machine.static_ip = "192.168.1.2";
            machine.is_home_server = true;
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
  };
}