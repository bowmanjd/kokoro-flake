{ lib, buildPythonPackage, fetchurl }:

buildPythonPackage rec {
  pname = "text2num";
  version = "3.0.2";
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/54/95/4266c644fd1f09ef0a32a596b83326c1d8b4c1ecb584584d088dbf6fa788/text2num-3.0.2-cp313-cp313-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
    hash = "sha256-WihXoooiTPM/Zhl3BTue8ntSJ6RaqDD5Ju9J1ugG4cg=";
  };

  # Wheel does not need compilation or check
  doCheck = false;
}
