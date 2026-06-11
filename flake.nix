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
        python3 = prev.python3.override {
          packageOverrides = pythonFinal: pythonPrev: {
            # ROCm PyTorch overrides
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
