{ }:

{
  packageFromCommit = { rev, packageName, cudaSupport ? false }:
    let
      src-url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
      nixpkgs-src = builtins.fetchTarball {
        url = src-url;
      };
      pkgs-at-commit = import nixpkgs-src {
        system = builtins.currentSystem;
        config = {
          cudaSupport = cudaSupport;
          allowUnfree = true;
        };
      };
    in
      pkgs-at-commit."${packageName}";
}