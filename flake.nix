{
  description = "nixos flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # use the unstable branch, usually behind masters by a few days
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    # nixpkgs.url = github:NixOS/nixpkgs/master; # use the master branch
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # for running unpatched binaries
    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # https://github.com/gmodena/nix-flatpak?tab=readme-ov-file
    nix-flatpak = {
      url = "github:gmodena/nix-flatpak";
    };
    # ags
    astal = {
      url = "github:aylur/astal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ags = {
      url = "github:aylur/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self, nix-flatpak, nixpkgs, home-manager,
      emacs-overlay, ags, astal, ...
  } @inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    modifiedAgs = ags.packages.${system}.default.overrideAttrs (oldAttrs: rec {
      nativeBuildInputs = oldAttrs.nativeBuildInputs or [] ++ [
        pkgs.wrapGAppsHook
        pkgs.gobject-introspection
      ];
      buildInputs = oldAttrs.buildInputs or [] ++ (with astal.packages.${system}; [
        astal3
        apps
        io
        hyprland
        mpris
        battery
        wireplumber
        network
        tray
        notifd
        # any other package
      ]);
    });
  in {
    nixosConfigurations.mahmooz = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
      };
      modules = [
        nix-flatpak.nixosModules.nix-flatpak
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            emacs-overlay.overlay
            (self: super: {
              my_emacs_git = (super.emacs-git.override { withImageMagick = true; withXwidgets = false; withPgtk = true; withNativeCompilation = true; withCompressInstall = false; withTreeSitter = true; withGTK3 = true; withX = false; }).overrideAttrs (oldAttrs: rec {
                imagemagick = pkgs.imagemagickBig;
              });
            })
            # enable pgtk so its not pixelated on wayland
            (self: super: {
              my_emacs = (super.emacs-git.override { withImageMagick = true; withXwidgets = false; withPgtk = true; withNativeCompilation = true; withCompressInstall = false; withTreeSitter = true; withGTK3 = true; withX = false; }).overrideAttrs (oldAttrs: rec {
                imagemagick = pkgs.imagemagickBig;
              });
            })
          ];
          environment.systemPackages = with pkgs; [
            # my_emacs_git.emacsWithPackages
            # ((emacsPackagesFor my_emacs_git).emacsWithPackages(epkgs: with epkgs; [
            #   # vterm
            #   treesit-grammars.with-all-grammars
            # ]))
            ((emacsPackagesFor my_emacs).emacsWithPackages(epkgs: with epkgs; [
              # vterm
              treesit-grammars.with-all-grammars
            ]))
            # (pkgs.writeShellScriptBin "emacsold" ''
            #   exec ${((emacsPackagesFor my_emacs).emacsWithPackages(epkgs: with epkgs; [treesit-grammars.with-all-grammars]))}/bin/emacs --init-directory=/home/mahmooz/emacsold "$@"
            # '')
            modifiedAgs
          ];
        })
        ./desktop.nix

        # https://github.com/thiagokokada/nix-alien
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            self.inputs.nix-alien.overlays.default
          ];
          environment.systemPackages = with pkgs; [
            nix-alien
          ];
        })

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.mahmooz = import ./home.nix;
            home-manager.backupFileExtension = "hmbkup";
          }
      ];
    };
    # homeConfigurations = {
    #   "mahmooz@mahmooz" = home-manager.lib.homeManagerConfiguration {
    #     modules = [
    #       ./home.nix
    #     ];
    #   };
    # };
  };
}