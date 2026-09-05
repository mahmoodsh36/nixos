{ config, pkgs, lib, ... }:

let
  emacs_pkg =
    if config.machine.is_linux && config.machine.can_compile
    then pkgs.emacs-pgtk
    else pkgs.emacs;
in
{
  config = {
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
            tree-sitter-tsx
            tree-sitter-yaml
          ]
        ))
      ])))
    ];
  };
}
