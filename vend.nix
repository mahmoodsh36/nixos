{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
  pname = "vend";
  version = "0.1.5";

  src = pkgs.fetchFromGitHub {
    owner = "fosskers";
    repo = "vend";
    rev = "8e399448553ee4b3be95a440b8a135ffdbe3074a";
    sha256 = "sha256-7+n3EUteOFwAg849rsufGmXgZ8ULETp+0ebK1bdlQdw=";
  };

  nativeBuildInputs = [];
  buildInputs = [ pkgs.ecl ];

  buildPhase = ''
    export HOME=$PWD
    ${pkgs.ecl}/bin/ecl --load build.lisp
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp -v vend $out/bin/
  '';

  meta = with pkgs.lib; {
    description = "Vend program built with ECL";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}