# https://github.com/nathan-gs/nix-conf/blob/f4665bbf4b1ab6f26456e051258affae8a738c8a/pkgs/python/autogen-core.nix
{ lib, buildPythonPackage, fetchPypi, pkgs }:

pkgs.python313.pkgs.buildPythonPackage rec {
  pname = "autogen-ext";
  version = "0.4.5";

  src = fetchPypi {
    inherit version;
    pname = "autogen_ext";
    hash  = "sha256-zO4JPc17zZedbcex8z1QhXR66ur+4Idm4un9FeUgyFI=";
  };

  propagatedBuildInputs = with pkgs.python313Packages; [
    (callPackage ./autogen-core.nix { pkgs = pkgs; })
    # langchain
    langchain-core
    # azure
    azure-core
    azure-identity
    (callPackage ./azure-ai-inference.nix { pkgs = pkgs; })
    # docker
    docker
    # openai
    openai
    tiktoken
    aiofiles
    # file-surfer
    (callPackage ./autogen-agentchat.nix { pkgs = pkgs; })
    markitdown
    # graphrag
    #graphrag issue with gensim
    # web-surfer
    playwright
    pillow
    magentic-one

    # video-surfer
    #opencv-python
    #ffmpeg-python
    #openai-whisper

    # diskcache
    diskcache

    # jupyter-executor
    ipykernel
    nbclient

    # rich
    rich

  ];

  nativeBuildInputs = with pkgs.python313Packages; [
    hatchling
  ];

  buildPhase = ''
    hatchling build
  '';

  doCheck = true;

  pythonImportsCheck = [ "autogen_ext" ];
}