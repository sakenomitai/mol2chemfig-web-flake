{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
}:

buildPythonPackage rec {
  pname = "pubchempy";
  version = "1.0.5";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-CPCyqCpcql1h4Uk11lXaVUYC17Vob+Zhq1hMiC//9iM=";
  };

  build-system = [ setuptools ];

  # the test suite queries the live PubChem API
  doCheck = false;

  pythonImportsCheck = [ "pubchempy" ];

  meta = {
    description = "Python wrapper around the PubChem PUG REST API";
    homepage = "https://github.com/mcs07/PubChemPy";
    license = lib.licenses.mit;
  };
}
