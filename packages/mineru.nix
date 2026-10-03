{
  lib,
  python3,
  fetchFromGitHub,
  fetchPypi,
  rustPlatform,
  cargo,
  rustc,
  cmake,
  ninja,
  git,
}:

let
  python = python3.override {
    self = python;
    packageOverrides = pyself: pysuper: {
      metafile-render = pyself.buildPythonPackage rec {
        pname = "metafile-render";
        version = "0.3.0";
        pyproject = true;
        src = fetchPypi {
          pname = "metafile_render";
          inherit version;
          hash = "sha256-mHtIOhO0sEjx2V7FmQ8tBv86klUNE7Locd/UiDYXHnc=";
        };
        build-system = [ pyself.setuptools ];
        dependencies = with pyself; [
          pillow
          pyclipper
        ];
        pythonImportsCheck = [ "metafile_render" ];
      };

      pypptx-with-oxml = pyself.buildPythonPackage rec {
        pname = "pypptx-with-oxml";
        version = "1.0.3";
        pyproject = true;
        src = fetchPypi {
          pname = "pypptx_with_oxml";
          inherit version;
          hash = "sha256-oJPYyOmd/NATHqmLTbwKCkCt9Ehp7bt0xX0MuHuOQgg=";
        };
        build-system = [ pyself.setuptools ];
        dependencies = with pyself; [
          pillow
          xlsxwriter
          lxml
          typing-extensions
        ];
        pythonImportsCheck = [ "pptx" ];
      };

      mathml2omml = pyself.buildPythonPackage rec {
        pname = "mathml2omml";
        version = "0.0.2";
        pyproject = true;
        src = fetchPypi {
          inherit pname version;
          hash = "sha256-xnsonNCSCMS288T3RlP22G7f2P/0wY5slaevqZlOcyM=";
        };
        build-system = [ pyself.setuptools ];
        pythonImportsCheck = [ "mathml2omml" ];
      };

      docvortex = pyself.buildPythonPackage rec {
        pname = "docvortex";
        version = "0.5.8";
        pyproject = true;
        src = fetchPypi {
          inherit pname version;
          hash = "sha256-KccRBCLHJYr4WmsEIZWo1Vy2hdOzCc/sxy9u7fmZCgs=";
        };
        cargoDeps = rustPlatform.fetchCargoVendor {
          inherit pname version src;
          hash = "sha256-0Z4LC2DbdiXj1v9dvUjbCAK/9rGM9Ttjs8KpxSWKc9M=";
        };
        env.DOCVORTEX_BUILD_NATIVE = "1";
        nativeBuildInputs = [
          rustPlatform.cargoSetupHook
          cargo
          rustc
        ];
        build-system = with pyself; [
          setuptools
          setuptools-rust
        ];
        # rl_accel (reportlab[accel]) is only a speedup and is not in nixpkgs
        pythonRelaxDeps = true;
        dependencies = with pyself; [
          click
          loguru
          numpy
          pillow
          pypdfium2
          pypdf
          pydantic
          metafile-render
          ftfy
          fonttools
          beautifulsoup4
          lxml
          nh3
          python-docx
          pypptx-with-oxml
          mammoth
          openpyxl
          olefile
          pylatexenc
          latex2mathml
          mathml2omml
          resvg-py
          reportlab
          ziamath
          magika
          opencv-python
        ];
        pythonImportsCheck = [
          "docvortex"
          "docvortex._native"
        ];
      };

      mineru-llama-cpp = pyself.buildPythonPackage rec {
        pname = "mineru-llama-cpp";
        version = "0.1.2";
        pyproject = true;
        src = fetchFromGitHub {
          owner = "opendatalab";
          repo = "mineru-llama-cpp";
          tag = "v${version}";
          fetchSubmodules = true;
          hash = "sha256-alvAlYWNsAmqKcd/huul0kMR1kxvEjJoIGRLjwvZpcY=";
        };
        # cmake runs `git apply` for patches/llama.cpp
        nativeBuildInputs = [
          cmake
          ninja
          git
        ];
        dontUseCmakeConfigure = true;
        build-system = with pyself; [
          scikit-build-core
          pybind11
        ];
        pythonImportsCheck = [ "mineru_llama_cpp" ];
      };

      mineru-vl-utils = pyself.buildPythonPackage rec {
        pname = "mineru-vl-utils";
        version = "2.0.5";
        pyproject = true;
        src = fetchFromGitHub {
          owner = "opendatalab";
          repo = "mineru-vl-utils";
          tag = "mineru_vl_utils-${version}-released";
          hash = "sha256-YoogNpvxzpi9AUa/6KFkSS+D8kvhkJjBAGyBUfT63fY=";
        };
        # release tags carry the previous version, ci bumps it when publishing
        postPatch = ''
          echo '__version__ = "${version}"' > mineru_vl_utils/version.py
        '';
        build-system = [ pyself.setuptools ];
        dependencies = with pyself; [
          httpx
          httpx-retries
          aiofiles
          pillow
          pydantic
          loguru
          tqdm
        ];
        pythonImportsCheck = [ "mineru_vl_utils" ];
      };
    };
  };
in
python.pkgs.buildPythonApplication rec {
  pname = "mineru";
  version = "4.0.10";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "opendatalab";
    repo = "MinerU";
    tag = "mineru-${version}-released";
    hash = "sha256-821VJ8BcJrJAuJ8S+NcU8SyPSOOcEUdoGImfYJsxeFI=";
  };

  # release tags carry the previous version, ci bumps it when publishing
  postPatch = ''
    echo '__version__ = "${version}"' > mineru/version.py
  '';

  build-system = [ python.pkgs.setuptools ];

  # mineru[torch] is a self reference, the torch extra is listed below.
  # modelscope (lazily imported alternative model mirror) is marked insecure in nixpkgs
  pythonRemoveDeps = [
    "mineru"
    "modelscope"
  ];
  pythonRelaxDeps = true;

  dependencies = with python.pkgs; [
    docvortex
    # not cached, and its test suite tries to reach the network
    (gradio.overridePythonAttrs { doCheck = false; })
    mineru-vl-utils
    mineru-llama-cpp
    click
    loguru
    numpy
    tqdm
    requests
    httpx
    pillow
    pypdfium2
    pyyaml
    packaging
    huggingface-hub
    hf-xet
    filelock
    json-repair
    opencv-python
    openai
    beautifulsoup4
    tinycss2
    aiosqlite
    watchfiles
    fastapi
    python-multipart
    uvicorn
    pydantic
    typing-extensions
    typer
    rich
    jieba
    onnxruntime
    ftfy
    shapely
    pyclipper
    tokenizers
    # torch extra, pulled in by default upstream on darwin arm64
    torch
    torchvision
    transformers
    accelerate
    safetensors
  ];

  # subprocesses (doclib server, router workers) run `sys.executable -m mineru...`
  preFixup = ''
    makeWrapperArgs+=(--prefix PYTHONPATH : "$out/${python.sitePackages}:$PYTHONPATH")
  '';

  pythonImportsCheck = [ "mineru" ];

  meta = {
    description = "Convert PDF and office documents into Markdown and JSON";
    homepage = "https://github.com/opendatalab/MinerU";
    mainProgram = "mineru";
  };
}
