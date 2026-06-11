{ lib, buildPythonPackage, fetchPypi, hatchling, espeakng-loader, joblib, segments, tqdm, attrs, packaging, dlinfo, typing-extensions }:

buildPythonPackage rec {
  pname = "phonemizer-fork";
  version = "3.3.2";
  format = "pyproject";

  src = fetchPypi {
    pname = "phonemizer_fork";
    inherit version;
    hash = "sha256-EOFugn0EQ7CHBi4htV6AXACYnPE0Oy6B5zTK5fbAz2k=";
  };

  nativeBuildInputs = [
    hatchling
  ];

  propagatedBuildInputs = [
    espeakng-loader
    joblib
    segments
    tqdm
    attrs
    packaging
    dlinfo
    typing-extensions
  ];

  # Skip tests
  doCheck = false;
}
