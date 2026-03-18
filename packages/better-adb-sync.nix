{
  lib,
  python3Packages,
  fetchFromGitHub,
  android-tools,
}:

python3Packages.buildPythonApplication rec {
  pname = "better-adb-sync";
  version = "1.4.1";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "jpstotz";
    repo = "better-adb-sync";
    rev = "0047c6486b0f5b21bb4927c2621b9f93819d002a";
    hash = "sha256-Pd1mxO0H0Cu7CPrh9WUEfTjkjeCNb10uUFsD3zWWiuw=";
  };

  nativeBuildInputs = [
    python3Packages.setuptools
  ];

  propagatedBuildInputs = [
    android-tools
  ];

  meta = with lib; {
    homepage = "https://github.com/jpstotz/better-adb-sync";
    platforms = platforms.all;
    mainProgram = "adbsync";
  };
}