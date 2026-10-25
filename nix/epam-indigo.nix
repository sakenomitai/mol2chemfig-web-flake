{
  lib,
  stdenv,
  python,
  buildPythonPackage,
  fetchurl,
  autoPatchelfHook,
  fontconfig,
  freetype,
}:

let
  version = "1.46.0";

  # Indigo is a large C++ toolkit with many vendored dependencies; the
  # manylinux wheels from PyPI bundle the native libraries ready to use.
  wheels = {
    x86_64-linux = {
      platform = "manylinux1_x86_64";
      hash = "sha256-IFQVkA7ZGb+/KpUa8B9Sy9zHq0NVkUOjG+m5x+C/15o=";
    };
    aarch64-linux = {
      platform = "manylinux2014_aarch64";
      hash = "sha256-k2d3Q57il0GJowNUgJ3rG6OrU+4UmkJ7Ffa9ZXGECUE=";
    };
  };

  system = stdenv.hostPlatform.system;
  wheel = wheels.${system} or (throw "epam-indigo: no prebuilt wheel for ${system}");
in
buildPythonPackage {
  pname = "epam-indigo";
  inherit version;
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/py3/e/epam_indigo/epam_indigo-${version}-py3-none-${wheel.platform}.whl";
    inherit (wheel) hash;
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  # libindigo needs libgcc_s; the renderer also links freetype and fontconfig
  buildInputs = [
    stdenv.cc.cc.lib
    fontconfig
    freetype
  ];

  pythonImportsCheck = [ "indigo" ];

  # importing indigo doesn't load libindigo.so yet; instantiating it does
  checkPhase = ''
    runHook preCheck
    PYTHONPATH=$out/${python.sitePackages}:$PYTHONPATH \
      ${python.interpreter} -c 'from indigo import Indigo; print(Indigo().version())'
    runHook postCheck
  '';

  meta = {
    description = "Universal organic chemistry toolkit (Python bindings with bundled native libraries)";
    homepage = "https://lifescience.opensource.epam.com/indigo/";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames wheels;
  };
}
