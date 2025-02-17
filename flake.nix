{
  description = "nixos flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # use the unstable branch, usually behind masters by a few days
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    # nixpkgs.url = "github:NixOS/nixpkgs/master"; # use the master branch
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wezterm-flake = {
      url = "github:wez/wezterm/ee0c04e735fb94cb5119681f704fb7fa6731e713?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lem = {
      url = "github:lem-project/lem";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # yet another pinning mechanism (beside the fact that this is a flake..)
    pinned-pkgs.url = "github:NixOS/nixpkgs/2ff53fe64443980e139eaa286017f53f88336dd0";
  };

  outputs = {
    self, nixpkgs, home-manager,
      wezterm-flake, ...
  } @inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    pinned-pkgs = import inputs.pinned-pkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
      config.cudaSupport = (import ./per_machine_vars.nix {}).enable_nvidia;
    };
  in {
    nixosConfigurations.mahmooz = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
      };
      modules = [
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
      ];
    };
  };
}