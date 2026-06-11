{ lib, python3, fetchFromGitHub, espeak-ng, ffmpeg
, espeakng-loader, phonemizer-fork, text2num, en-core-web-sm
}:

python3.pkgs.buildPythonPackage rec {
  pname = "kokoro-fastapi";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "remsky";
    repo = "Kokoro-FastAPI";
    rev = "v${version}";
    hash = "sha256-I2tf3sFt0GqphKNFJHXlQKDgeR34sCOSHMLMSNXNLqY=";
  };

  format = "pyproject";

  postPatch = ''
    # Clean up dependencies in pyproject.toml to remove exact/unsupported version pins
    python3 -c '
    import re
    with open("pyproject.toml", "r") as f:
        lines = f.readlines()
    new_lines = []
    in_deps = False
    for line in lines:
        if "dependencies = [" in line:
            in_deps = True
            new_lines.append(line)
            continue
        if in_deps and re.match(r"^\s*\]", line):
            in_deps = False
            new_lines.append(line)
            continue
        if in_deps:
            m = re.match(r"^(\s*)\"([^\"]+)\"(,?.*)$", line)
            if m:
                indent, dep, suffix = m.groups()
                if " @ " in dep:
                    dep = dep.split(" @ ")[0].strip()
                if "misaki[" in dep:
                    dep = "misaki[en]"
                else:
                    dep = re.split(r"==|>=|>|<|<=|~=", dep)[0].strip()
                new_lines.append(f"{indent}\"{dep}\"{suffix}\n")
                continue
        new_lines.append(line)
    with open("pyproject.toml", "w") as f:
        f.writelines(new_lines)
    '
  '';

  propagatedBuildInputs = with python3.pkgs; [
    # Core app deps
    fastapi uvicorn pydantic pydantic-settings python-dotenv sqlalchemy
    numpy scipy soundfile regex aiofiles tqdm requests munch tiktoken
    loguru openai pydub matplotlib mutagen psutil spacy inflect av click

    # Flake-provided packages
    espeakng-loader phonemizer-fork text2num en-core-web-sm

    # Upstream nixpkgs packages for kokoro/misaki ecosystem
    kokoro misaki
    spacy-curated-transformers
    num2words transformers
  ];

  nativeBuildInputs = with python3.pkgs; [ setuptools wheel ];

  # Runtime native tools
  makeWrapperArgs = [
    "--prefix" "PATH" ":" "${lib.makeBinPath [ espeak-ng ffmpeg ]}"
  ];

  doCheck = false;

  # Include the web player and voice files in the output
  postInstall = ''
    # Copy web player and api directory to share
    mkdir -p $out/share/kokoro-fastapi
    cp -r $src/web $out/share/kokoro-fastapi/web
    cp -r $src/api $out/share/kokoro-fastapi/api

    # Substitute wrapper script
    mkdir -p $out/bin
    substitute ${../../wrapper.sh} $out/bin/kokoro-fastapi \
      --replace-fail "@python@" "${python3.withPackages (ps: propagatedBuildInputs)}" \
      --replace-fail "@out@" "$out"
    chmod +x $out/bin/kokoro-fastapi
  '';

  passthru = {
    python = python3;
  };

  meta = with lib; {
    description = "OpenAI-compatible FastAPI server for Kokoro TTS";
    homepage = "https://github.com/remsky/Kokoro-FastAPI";
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
