# https://github.com/nathan-gs/nix-conf/blob/f4665bbf4b1ab6f26456e051258affae8a738c8a/pkgs/python/autogen-core.nix
{ lib, buildPythonPackage, fetchPypi, fetchurl, pkgs }:

pkgs.python313.pkgs.buildPythonApplication rec {
  pname = "autogen-core";
  version = "0.4.5";

  src = fetchPypi {
    inherit version;
    pname = "autogen_core";
    hash  = "sha256-2+CbpYW+8YoJm/vMSUOFyzgwhWM+6p4/0l0NOTk6U74=";
  };

  propagatedBuildInputs = with pkgs.python313Packages; [
    pillow
    typing-extensions
    pydantic
    protobuf
    opentelemetry-api
    jsonref
  ];

  nativeBuildInputs = with pkgs.python313Packages; [
    hatchling
  ];

  buildPhase = ''
    hatchling build
  '';

  doCheck = true;

  pythonImportsCheck = [ "autogen_core" ];
}