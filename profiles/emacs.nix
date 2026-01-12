{ config, pkgs, lib, inputs, pkgs-unstable, myutils, pkgs-pinned, ... }:

let
  emacs_base_pkg = if config.machine.is_darwin
                   then pkgs.emacs-30
                   else pkgs.emacs;
  emacs_pkg = (emacs_base_pkg.override {
    withImageMagick = false;
    withNativeCompilation = true;
    withCompressInstall = false;
    withTreeSitter = true;
  } // lib.optionalAttrs config.machine.is_linux {
    withXwidgets = false;
    withPgtk = true;
    withGTK3 = true;
    withX = false;
  }).overrideAttrs (oldAttrs: rec {
    imagemagick = pkgs.imagemagickBig;
  });
in
{
  config = lib.mkIf config.machine.is_desktop {
    # packages
    environment.systemPackages = with pkgs; [
      (lib.mkIf (!config.machine.is_vm) ((emacsPackagesFor emacs_pkg).emacsWithPackages(epkgs: with epkgs; [
        (treesit-grammars.with-grammars (
          p: with p; [
            tree-sitter-bash
            tree-sitter-css
            tree-sitter-html
            tree-sitter-javascript
            tree-sitter-json
            tree-sitter-nix
            tree-sitter-python
            tree-sitter-rust
            tree-sitter-typescript
            tree-sitter-yaml
          ]
        ))
      ])))
    ];
  };
}