# https://github.com/nathan-gs/nix-conf/blob/f4665bbf4b1ab6f26456e051258affae8a738c8a/pkgs/python/autogen-core.nix
{ lib, buildPythonPackage, fetchPypi, fetchurl, pkgs }:

pkgs.python313.pkgs.buildPythonPackage rec {
  pname = "autogen-agentchat";
  version = "0.4.5";

  src = fetchPypi {
    inherit version;
    pname = "autogen_agentchat";
    hash  = "sha256-qNVJO07GxF9NQMM8bTu5imQJ96ZCjOT6lkXlG/4tdAg=";
  };

  propagatedBuildInputs = with pkgs.python313Packages; [
    (callPackage ./autogen-core.nix { pkgs = pkgs; })
  ];

  nativeBuildInputs = with pkgs.python313Packages; [
    hatchling
  ];

  buildPhase = ''
    hatchling build
  '';

  doCheck = true;

  pythonImportsCheck = [ "autogen_agentchat" ];
}