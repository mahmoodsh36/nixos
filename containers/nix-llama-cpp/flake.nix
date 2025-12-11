{
  description = "NixOS Vulkan container environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llama-cpp-flake = {
      url = "github:ggml-org/llama.cpp";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixgl, llama-cpp-flake, ... }:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ nixgl.overlay ];
      };

      # wrapper script that uses nixGL with fedora's virtio vulkan driver
      nixVulkanVirtio = pkgs.writeShellScriptBin "nixVulkanVirtio" ''
        export VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/virtio_icd.aarch64.json"
        export VK_DRIVER_FILES="/usr/share/vulkan/icd.d/virtio_icd.aarch64.json"
        exec ${pkgs.nixgl.auto.nixGLDefault}/bin/nixGL "$@"
      '';
    in {
      packages.${system} = {
        default = self.packages.${system}.env;

        # llama.cpp with vulkan support
        llama-cpp-vulkan = llama-cpp-flake.packages.${system}.vulkan;

        # wrapper for vulkan apps to use fedora's virtio driver
        inherit nixVulkanVirtio;

        # environment with all packages bundled
        env = pkgs.buildEnv {
          name = "nixos-vulkan-env";
          paths = [
            nixVulkanVirtio
            pkgs.nixgl.auto.nixGLDefault

            # llama.cpp with Vulkan
            llama-cpp-flake.packages.${system}.vulkan

            # basic utilities
            pkgs.bash
            pkgs.coreutils
            pkgs.curl
            pkgs.jq
            pkgs.git
            pkgs.htop
          ];
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          nixVulkanVirtio
          pkgs.nixgl.auto.nixGLDefault
          llama-cpp-flake.packages.${system}.vulkan
          pkgs.curl
          pkgs.jq
        ];

        shellHook = ''
          echo "NixOS vulkan environment loaded"
          echo "use 'nixVulkanVirtio llama-cli --list-devices' to run with vulkan"
        '';
      };
    };
}