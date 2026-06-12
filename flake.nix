{
  description = "A Nix flake for running Kokoro TTS natively with ROCm/CPU support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      # Define the overlay that injects our custom python packages and fastapi server
      localOverlay = final: prev: {
        # Stub out aotriton — its FlashAttention kernels require MFMA instructions
        # only available on CDNA/RDNA GPUs. The MI50 (gfx906, Vega 20) can't use
        # them; PyTorch falls back to Math SDPA regardless. This avoids hours of
        # compilation for a library that produces no usable output on this hardware.
        rocmPackages = prev.rocmPackages.overrideScope (rfinal: rprev: {
          aotriton = prev.emptyDirectory.overrideAttrs {
            name = "aotriton-stub";
          };
        });

        python3 = prev.python3.override {
          packageOverrides = pythonFinal: pythonPrev: {
            # ROCm PyTorch (without aotriton, see above)
            torchWithRocm = pythonPrev.torch.override {
              triton = pythonFinal.triton-no-cuda;
              rocmSupport = true;
              cudaSupport = false;
            };
            torch = pythonFinal.torchWithRocm;

            # Custom packages
            espeakng-loader = pythonFinal.callPackage ./pkgs/espeakng-loader { };
            phonemizer-fork = pythonFinal.callPackage ./pkgs/phonemizer-fork { };
            phonemizer = pythonFinal.phonemizer-fork;
            text2num = pythonFinal.callPackage ./pkgs/text2num { };
            en-core-web-sm = pythonFinal.callPackage ./pkgs/en-core-web-sm { };

            # Override pydub to use standard ffmpeg instead of ffmpeg-full (avoids compiling ffmpeg-full)
            pydub = let
              args = pythonPrev.pydub.override.__functionArgs or {};
            in
              pythonPrev.pydub.override (
                if builtins.hasAttr "ffmpeg-full" args then
                  { ffmpeg-full = final.ffmpeg; }
                else
                  { ffmpeg = final.ffmpeg; }
              );

            # Disable wandb to prevent pulling in opencv, scikit-image, moviepy, and pillow-heif (avoids compiling opencv)
            wandb = null;
          };
        };
        python3Packages = final.python3.pkgs;

        kokoro-fastapi = final.callPackage ./pkgs/kokoro-fastapi {
          inherit (final.python3Packages) espeakng-loader phonemizer-fork text2num en-core-web-sm;
        };
      };
    in
    {
      # Expose default overlay
      overlays.default = localOverlay;

      # Expose NixOS module
      nixosModules.default = import ./nixos-module.nix;
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ localOverlay ];
          config.allowUnfree = true;
        };
      in
      {
        packages = {
          default = pkgs.kokoro-fastapi;
          kokoro-fastapi = pkgs.kokoro-fastapi;
          espeakng-loader = pkgs.python3Packages.espeakng-loader;
          phonemizer-fork = pkgs.python3Packages.phonemizer-fork;
          text2num = pkgs.python3Packages.text2num;
          en-core-web-sm = pkgs.python3Packages.en-core-web-sm;
        };
      }
    );
}
