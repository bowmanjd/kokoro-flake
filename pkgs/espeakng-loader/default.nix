{ lib, buildPythonPackage, espeak-ng, writeTextDir }:

let
  loaderSource = writeTextDir "espeakng_loader/__init__.py" ''
    import ctypes
    _lib = None

    def get_library_path():
        return "${espeak-ng}/lib/libespeak-ng.so"

    def get_data_path():
        return "${espeak-ng}/share/espeak-ng-data"

    def load_library():
        global _lib
        if _lib is None:
            _lib = ctypes.CDLL(get_library_path())
        return _lib
  '';
in
buildPythonPackage {
  pname = "espeakng-loader";
  version = "0.2.4";
  src = loaderSource;
  format = "setuptools";
  preBuild = ''
    cat <<EOF > setup.py
    from setuptools import setup
    setup(name='espeakng-loader', version='0.2.4', packages=['espeakng_loader'])
    EOF
  '';
}
