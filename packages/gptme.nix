{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

let
  # Override mcp to fix the broken patch in nixpkgs
  mcp = python3Packages.mcp.overridePythonAttrs (old: {
    # Disable the broken substitution that fails
    postPatch = "";
    # Disable checks since the test patch was the issue
    doCheck = false;
  });

  # multiprocessing-logging is not in nixpkgs, build it inline
  multiprocessing-logging = python3Packages.buildPythonPackage rec {
    pname = "multiprocessing-logging";
    version = "0.3.4";
    format = "setuptools";

    src = fetchFromGitHub {
      owner = "jruere";
      repo = "multiprocessing-logging";
      rev = "v${version}";
      hash = "sha256-rb+llnp0NJfQMwZ+GVnVjDlSJsRMsMyAReaR6DW9YUU=";
    };

    doCheck = false;

    meta = with lib; {
      description = "Logging handler for multiprocessing library";
      homepage = "https://github.com/jruere/multiprocessing-logging";
      license = licenses.lgpl3Only;
    };
  };
in
python3Packages.buildPythonApplication rec {
  pname = "gptme";
  version = "unstable-2026-01-08";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "gptme";
    repo = "gptme";
    rev = "7d539dfbfec1a28a8fde9f297d54be167475ac2a";
    hash = "sha256-W/ouPQ02d6L5RHYcgviEEKCW5brppB5wNKX7JAB5tOM=";
  };

  build-system = with python3Packages; [
    poetry-core
    poetry-dynamic-versioning
  ];

  # Disable strict dependency version checking since nixpkgs has newer versions
  # that are functionally compatible
  pythonRelaxDeps = true;

  dependencies = with python3Packages; [
    # core dependencies
    click
    click-default-group
    python-dotenv
    rich
    tabulate
    pick
    tiktoken
    tomlkit
    typing-extensions
    platformdirs
    lxml
    pyyaml
    python-dateutil
    deprecated
    questionary
    pillow
    pydantic
    json-repair

    # providers
    openai
    anthropic

    # tools
    ipython
    bashlex
  ] ++ [
    mcp  # our fixed mcp
    multiprocessing-logging  # inline package
  ];

  optional-dependencies = with python3Packages; {
    server = [ flask flask-cors ];
    browser = [ playwright ];
    datascience = [ matplotlib pandas numpy ];
  };

  # disable tests as they require API keys
  doCheck = false;

  # gptme tries to create config/log directories on import, which fails in sandbox
  pythonImportsCheck = [ ];

  meta = with lib; {
    description = "Powerful AI agent for coding and general tasks with shell, code execution, and file editing";
    homepage = "https://gptme.org/";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "gptme";
    platforms = platforms.all;
  };
}
