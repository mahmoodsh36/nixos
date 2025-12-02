{ system }:

{
  packageFromCommit = { rev, packageName, sha256, cudaSupport ? false }:
    let
      src-url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
      nixpkgs-src = builtins.fetchTarball {
        url = src-url;
        sha256 = sha256;
      };
      pkgs-at-commit = import nixpkgs-src {
        inherit system;
        config = {
          cudaSupport = cudaSupport;
          allowUnfree = true;
        };
      };
    in
      pkgs-at-commit."${packageName}";
}