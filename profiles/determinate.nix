# this is for macos
{ config, pkgs, lib, inputs, myutils, ... }:

{
  # let determinate nix handle your nix configuration
  nix.enable = false;

  # # custom determinate nix settings written to /etc/nix/nix.custom.conf
  determinate-nix.customSettings = {
    # enables parallel evaluation (remove this setting or set the value to 1 to disable)
    eval-cores = 0;
    extra-experimental-features = [
      "build-time-fetch-tree" # enables build-time flake inputs
      "parallel-eval" # enables parallel evaluation
      "external-builders"
    ];
    external-builders = builtins.toJSON [{
      systems = [ "aarch64-linux" "x86_64-linux" ];
      program = "/usr/local/bin/determinate-nixd";
      args = [
        "builder"
        "--memory-size"
        "30000000000" # 30GB?
        "--cpu-count"
        "1" # according to detsys's blog increasing this makes things slower
      ];
    }];
    extra-trusted-users = ["${config.machine.user}" "@admin" "@root" "@sudo" "@wheel" "@staff"];
    keep-outputs = true;
    keep-derivations = true;
    # flake-registry = "/etc/nix/flake-registry.json";
  };
}