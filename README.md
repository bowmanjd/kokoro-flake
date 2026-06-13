# kokoro-flake

A Nix flake for running Kokoro TTS natively with ROCm and CPU support, providing an OpenAI-compatible FastAPI server and a web-based player UI. The focus is primarily on ensuring this works for gfx906 cards like AMD Instict MI50, and actually skips some optimizations for newer cards to avoid long builds. Also the focus is on English to speed compile time, but that of course could be switched out for other languages.

This flake packages the FastAPI server from [remsky/Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI) and includes a NixOS module to easily deploy it as a systemd service, replacing resource-intensive container wrappers.

## Features

- Native ROCm & CPU Acceleration: Native execution using system ROCm/CPU packages
- FastAPI OpenAI-Compatible Server: Served via the `kokoro-fastapi` package ([pkgs/kokoro-fastapi/default.nix](file:///home/bowmanjd/devel/kokoro-flake/pkgs/kokoro-fastapi/default.nix)).
- Integrated Web UI: Serves a web-based TTS player at `/web/`.
- Automatic Model Downloads: A systemd oneshot helper service automatically downloads required model weights (`kokoro-v1_0.pth` and `config.json`) from GitHub releases on startup.
- Compilation Optimizations:
  - Stubs CDNA/RDNA-only Triton kernel builds (empty `gpuTargets` in `aotriton`) to avoid hours of useless compilation on older hardware.
  - Removes `wandb` and `opencv` dependencies to avoid large package builds.

## Usage

### 1. Add to Flake Inputs

In your system's `flake.nix`, add the input and configure it:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    kokoro-flake = {
      url = "github:bowmanjd/kokoro-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-torch.follows = "nixpkgs-torch";
    };

    # Pinned nixpkgs for PyTorch ROCm builds (highly recommended to avoid repeated long rebuilds)
    nixpkgs-torch.url = "github:NixOS/nixpkgs/8c91a71d13451abc40eb9dae8910f972f979852f";
  };
}
```

### 2. Configure NixOS Module and Overlay

Import the NixOS module and apply the package overlay to make `kokoro-fastapi` available:

```nix
# configuration.nix
{ inputs, pkgs, ... }: {
  imports = [
    inputs.kokoro-flake.nixosModules.default
  ];

  nixpkgs.overlays = [
    inputs.kokoro-flake.overlays.default
  ];

  # Enable the Kokoro TTS service
  services.kokoro = {
    enable = true;
    port = 8880;
    useGpu = true;
    openFirewall = true;
  };

  # (Optional) Disable global CUDA support to prevent rebuilds of cached packages like ffmpeg/opencv
  nixpkgs.config.cudaSupport = false;
}
```

## Configuration Options

The NixOS module ([nixos-module.nix](file:///home/bowmanjd/devel/kokoro-flake/nixos-module.nix)) exposes the following options under `services.kokoro`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `services.kokoro.enable` | bool | `false` | Enable the Kokoro TTS service. |
| `services.kokoro.port` | port | `8880` | Port for the Kokoro TTS API. |
| `services.kokoro.host` | string | `"0.0.0.0"` | Host to bind the FastAPI server to. |
| `services.kokoro.defaultVoice` | string | `"af_heart"` | Default voice for text-to-speech. |
| `services.kokoro.useGpu` | bool | `true` | Enable GPU acceleration. |
| `services.kokoro.stateDir` | string | `"/var/lib/kokoro"` | Directory for persistent state (models, cache, output). |
| `services.kokoro.openFirewall` | bool | `false` | Open the firewall port for Kokoro. |
| `services.kokoro.enableWebPlayer` | bool | `true` | Serve the web-based TTS player UI at `/web/`. |

## Available Packages

The default overlay ([flake.nix](file:///home/bowmanjd/devel/kokoro-flake/flake.nix)) provides:

- `kokoro-fastapi` - The FastAPI wrapper server.
- `python3Packages.espeakng-loader` - Spacy eSpeak loading utility.
- `python3Packages.phonemizer-fork` - Phonetization library fork.
- `python3Packages.text2num` - Text to number parser.
- `python3Packages.en-core-web-sm` - Spacy English language model.
