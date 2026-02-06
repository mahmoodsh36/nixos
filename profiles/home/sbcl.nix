{ lib, inputs, pkgs, config, config', ... }:

let
  mysbcl = (pkgs.sbcl.withPackages (ps: with ps; [
    inputs.cltpt.packages.${pkgs.system}.cltpt-lib
    # inputs.lem.packages.${pkgs.system}.lem-webview
    serapeum
    lparallel
    cl-csv
    jsown
    alexandria
    cl-ppcre
    # swank
    slynk
    cl-fad
    str
    py4cl # run python in common lisp
    cl-cuda
    clingon # command-line options parser
    ironclad # crypto functions
    fiveam # tests
    closer-mop
    local-time
    cl-json
  ]));
in
{
  config = lib.mkIf config'.machine.is_desktop {
    home.packages = [
      mysbcl
    ];
  };
}