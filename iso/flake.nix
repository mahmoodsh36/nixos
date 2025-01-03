{
  description = "a flake to build an iso";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    wezterm-flake = {
      url = "github:wez/wezterm/main?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
  };
  outputs = { self, nixpkgs, ... } @inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    nixosConfigurations =
      let
        mybase = {
          isoImage.squashfsCompression = "gzip -Xcompression-level 1";
          systemd.services.sshd.wantedBy = nixpkgs.lib.mkForce [ "multi-user.target" ];
          networking.wireless.enable = false; # installation-cd-minimal.nix sets that to true
          # users.users.root.openssh.authorizedKeys.keys = [ "<my ssh key>" ];
        };
      in
      {
        myiso = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          system = "x86_64-linux";
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ../desktop.nix
            mybase
          ];
        };
        example = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ mybase ];
        };
      };
  };
}