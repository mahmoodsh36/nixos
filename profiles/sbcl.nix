{ pkgs, pkgs-pinned, inputs, ... }:
let
  mysbcl = (pkgs-pinned.sbcl.withPackages (ps: with ps; [
    inputs.cltpt.packages.${pkgs.system}.cltpt-lib
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
mysbcl