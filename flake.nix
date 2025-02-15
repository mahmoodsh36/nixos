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
    # emacs-overlay = {
    #   url = "github:nix-community/emacs-overlay";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    # for running unpatched binaries
    # nix-alien = {
    #   url = "github:thiagokokada/nix-alien";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    # https://github.com/gmodena/nix-flatpak?tab=readme-ov-file
    # nix-flatpak = {
    #   url = "github:gmodena/nix-flatpak";
    # };
    wezterm-flake = {
      url = "github:wez/wezterm/11505b7083cc098203f899b023f31fe41abff0bd?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # hyprland = {
    #   url = "github:hyprwm/Hyprland";
    #   follows = "nixpkgs";
    # };
    # hyprland-plugins = {
    #   url = "github:hyprwm/hyprland-plugins";
    #   follows = "hyprland";
    #   inputs.hyprland.follows = "nixpkgs";
    # };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
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
      wezterm-flake, nix-vscode-extensions, ...
  } @inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    pinned-pkgs = inputs.pinned-pkgs.legacyPackages.${system};
  in {
    nixosConfigurations.mahmooz = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
      };
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            # nix-vscode-extensions.overlays.default
            # emacs-overlay.overlay
            (self: super: {
              my_emacs_git = (super.emacs-git.override { withImageMagick = true; withXwidgets = false; withPgtk = true; withNativeCompilation = true; withCompressInstall = false; withTreeSitter = true; withGTK3 = true; withX = false; }).overrideAttrs (oldAttrs: rec {
                imagemagick = pkgs.imagemagickBig;
              });
            })
            # enable pgtk so its not pixelated on wayland
            (self: super: {
              my_emacs = (super.emacs.override { withImageMagick = true; withXwidgets = false; withPgtk = true; withNativeCompilation = true; withCompressInstall = false; withTreeSitter = true; withGTK3 = true; withX = false; }).overrideAttrs (oldAttrs: rec {
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
            # ((emacsPackagesFor my_emacs_git).emacsWithPackages(epkgs: with epkgs; [
            #   # vterm
            #   treesit-grammars.with-all-grammars
            # ]))
            # (pkgs.writeShellScriptBin "emacsold" ''
            #   exec ${((emacsPackagesFor my_emacs).emacsWithPackages(epkgs: with epkgs; [treesit-grammars.with-all-grammars]))}/bin/emacs --init-directory=/home/mahmooz/emacsold "$@"
            # '')
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

        # https://github.com/thiagokokada/nix-alien
        # ({ pkgs, ... }: {
        #   nixpkgs.overlays = [
        #     self.inputs.nix-alien.overlays.default
        #   ];
        #   environment.systemPackages = with pkgs; [
        #     nix-alien
        #   ];
        # })

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