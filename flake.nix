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
    pinned-pkgs.url = "github:NixOS/nixpkgs/77b584d61ff80b4cef9245829a6f1dfad5afdfa3";
    # pinned-pkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
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
        };
        pinned-pkgs = import inputs.pinned-pkgs {
          system = "x86_64-linux";
        };
      in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit system;
            inherit pinned-pkgs;
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
      mahmooz = mkSystem [
        ./hardware-configuration.nix # hardware scan results
        ({ lib, ... }: {
          config = {
            boot.loader.efi.canTouchEfiVariables = true;
            machine.name = "mahmooz1";
            machine.is_desktop = true;
            machine.enable_nvidia = false;
          };
        })
        # we use the default networking configs of nixos on hetzner, here we use a custom config
        ./networking.nix
      ];
      hetzner = mkSystem [
        {
          config = {
            machine.name = "mahmooz3";
            machine.is_desktop = false;
            machine.enable_nvidia = false;
            boot.loader.grub.efiInstallAsRemovable = true;
          };
        }
        # inputs.disko.nixosModules.disko
        # ./disko-hetzner.nix
      ];
      desktop_iso = mkSystem [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        isobase
        {
          config = {
            machine.name = "mahmooz1";
            machine.is_desktop = true;
            machine.enable_nvidia = false;
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