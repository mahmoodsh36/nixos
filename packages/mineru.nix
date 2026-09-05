# env-specific fixes for the mineru venv (python-envs/mineru).
{ pkgs, python }:

final: prev:

let
  sitePackages = "lib/python${python.pythonVersion}/site-packages";
  mlxLibDir = "${final.mlx-metal}/${sitePackages}/mlx/lib";
in
{
  # both ship bin/ms and bin/modelscope, let modelscope win
  modelscope-hub = prev.modelscope-hub.overrideAttrs (_: {
    postInstall = "rm -f $out/bin/ms $out/bin/modelscope";
  });
}
// pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
  # uv_python.nix hardcodes mlx 0.30.0, our lock resolves 0.31.1. mlx and
  # mlx-metal must come from the same release, libmlx.dylib has no versioned SONAME.
  mlx = pkgs.stdenv.mkDerivation {
    pname = "mlx";
    version = "0.31.1";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/38/29/71fe1f68756f515856e6930973c23245810d4aa3cd22fddd719d86a709dc/mlx-0.31.1-cp312-cp312-macosx_14_0_arm64.whl";
      hash = "sha256-imOzGjmMlRnyuwyBzzhl2brKT/Vz/8MerUZdGChhhOg=";
    };
    nativeBuildInputs = [ pkgs.unzip ];
    propagatedBuildInputs = [ final.mlx-metal ];
    passthru.dependencies = { mlx-metal = [ ]; };
    unpackPhase = "unzip $src";
    installPhase = ''
      mkdir -p $out/${sitePackages}
      cp -r mlx* $out/${sitePackages}/
    '';
    postFixup = ''
      find $out/${sitePackages}/mlx -name "*.so" \
        -exec install_name_tool -add_rpath "${mlxLibDir}" {} \;
      find $out/${sitePackages}/mlx -name "*.so" \
        -exec install_name_tool -change @rpath/libmlx.dylib "${mlxLibDir}/libmlx.dylib" {} \;
    '';
  };

  mlx-metal = pkgs.stdenv.mkDerivation {
    pname = "mlx-metal";
    version = "0.31.1";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/39/66/2313497fdbc7fbadf8e026c09366e3f049f9114e65ca4edc23cdb8699186/mlx_metal-0.31.1-py3-none-macosx_14_0_arm64.whl";
      hash = "sha256-cHQRdBMdv3/dR5y3MOBuCMNY6sO/eQXZ6ITnlgz91bg=";
    };
    nativeBuildInputs = [ pkgs.unzip ];
    unpackPhase = "unzip $src";
    installPhase = ''
      # both wheels unpack into mlx/, these files are identical in both
      rm -f mlx/__main__.py mlx/_reprlib_fix.py mlx/extension.py mlx/py.typed mlx/utils.py

      mkdir -p $out/${sitePackages}
      cp -r * $out/${sitePackages}/
    '';
  };
}
