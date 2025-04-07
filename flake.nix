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
    # pkgs = nixpkgs.legacyPackages.${system};
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
      config.cudaSupport = (import ./per_machine_vars.nix {}).enable_nvidia;
    };
    pinned-pkgs = import inputs.pinned-pkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
      config.cudaSupport = (import ./per_machine_vars.nix {}).enable_nvidia;
    };
    isobase = {
      isoImage.squashfsCompression = "gzip -Xcompression-level 1";
      systemd.services.sshd.wantedBy = nixpkgs.lib.mkForce [ "multi-user.target" ];
      networking.wireless.enable = false; # installation-cd-minimal.nix sets that to true
      # users.users.root.openssh.authorizedKeys.keys = [ "<my ssh key>" ];
    };
    mkSystem = extraModules:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          inherit system;
        };
        modules = [
          {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.config.cudaSupport = (import ./per_machine_vars.nix {}).enable_nvidia;
          }
          ({ pkgs, pinned-pkgs, ... }: {
            nixpkgs.overlays = [
              # enable pgtk so its not pixelated on wayland
              (self: super: {
                my_emacs = (super.emacs.override { withImageMagick = true; withXwidgets = false; withPgtk = true; withNativeCompilation = true; withCompressInstall = false; withTreeSitter = true; withGTK3 = true; withX = false; }).overrideAttrs (oldAttrs: rec {
                  imagemagick = pkgs.imagemagickBig;
                });
              })
            ];
            environment.systemPackages = with pkgs; [
              ((emacsPackagesFor my_emacs).emacsWithPackages(epkgs: with epkgs; [
                treesit-grammars.with-all-grammars
              ]))
            ];
          })
          (if (import ./per_machine_vars.nix {}).is_desktop
           then ./desktop.nix
           else ./server.nix)
          {
            _module.args = { inherit pinned-pkgs; }; # need to pass it to desktop.nix
          }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.mahmooz = import ./home.nix;
            home-manager.backupFileExtension = "hmbkup";
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ] ++ extraModules;
      };
  in {
    nixosConfigurations = {
      mahmooz = mkSystem [
        ./hardware-configuration.nix # hardware scan results
      ];
      hetzner = mkSystem [
        {
          # otherwise my hetzner server's bootloader wont work
          boot.loader.grub.device = "nodev";
        }
        inputs.disko.nixosModules.disko
        ./disko-hetzner.nix
      ];
      myiso = mkSystem [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        isobase
      ];
    };
  };
}