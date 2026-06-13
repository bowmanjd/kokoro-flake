{ config, lib, pkgs, ... }:

let
  cfg = config.services.kokoro;
  kokoro-fastapi = pkgs.kokoro-fastapi;
in
{
  options.services.kokoro = {
    enable = lib.mkEnableOption "Kokoro TTS service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8880;
      description = "Port for the Kokoro TTS API.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host to bind to.";
    };

    defaultVoice = lib.mkOption {
      type = lib.types.str;
      default = "af_heart";
      description = "Default voice for TTS.";
    };

    useGpu = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable GPU acceleration.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/kokoro";
      description = "Directory for persistent state (models, cache, output).";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the firewall port for Kokoro.";
    };

    enableWebPlayer = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Serve the web-based TTS player UI at /web/.";
    };
  };

  config = lib.mkIf cfg.enable {
    # System user and group
    users.users.kokoro = {
      isSystemUser = true;
      group = "kokoro";
      extraGroups = [ "render" "video" ];
      home = cfg.stateDir;
      createHome = true;
    };
    users.groups.kokoro = {};

    # === Model Download (oneshot, before main service) ===
    systemd.services.kokoro-model-download = {
      description = "Download Kokoro TTS model weights";
      wantedBy = [ "kokoro.service" ];
      before = [ "kokoro.service" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      path = [ pkgs.wget pkgs.coreutils ];

      serviceConfig = {
        Type = "oneshot";
        User = "kokoro";
        Group = "kokoro";
        StateDirectory = "kokoro";
      };

      # Model must be at v1_0/kokoro-v1_0.pth relative to MODEL_DIR.
      # Uses wget from GitHub releases — same source the container's
      # download_model.py uses (verified working on nitrogen 2026-06-11,
      # 302→200 redirect, ~327 MB).
      script = ''
        MODEL_BASE="${cfg.stateDir}/models/v1_0"
        mkdir -p "$MODEL_BASE"

        if [ ! -f "$MODEL_BASE/kokoro-v1_0.pth" ]; then
          echo "Downloading kokoro-v1_0.pth (~327 MB)..."
          wget -q -c -O "$MODEL_BASE/kokoro-v1_0.pth" \
            https://github.com/remsky/Kokoro-FastAPI/releases/download/v0.1.4/kokoro-v1_0.pth
        fi

        if [ ! -f "$MODEL_BASE/config.json" ]; then
          echo "Downloading config.json..."
          wget -q -c -O "$MODEL_BASE/config.json" \
            https://github.com/remsky/Kokoro-FastAPI/releases/download/v0.1.4/config.json
        fi

        # Verify files exist and are non-empty
        for f in kokoro-v1_0.pth config.json; do
          if [ ! -s "$MODEL_BASE/$f" ]; then
            echo "ERROR: $f is missing or empty" >&2
            exit 1
          fi
        done

        echo "Model files ready at $MODEL_BASE"
      '';
    };

    # === Main Kokoro TTS Service ===
    systemd.services.kokoro = {
      description = "Kokoro TTS FastAPI Server";
      after = [ "network.target" "kokoro-model-download.service" ];
      requires = [ "kokoro-model-download.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        # Application config (pydantic-settings reads these as env vars)
        HOST = cfg.host;
        PORT = toString cfg.port;
        DEFAULT_VOICE = cfg.defaultVoice;
        USE_GPU = if cfg.useGpu then "true" else "false";

        # Paths — absolute paths override the os.path.join logic in paths.py
        MODEL_DIR = "${cfg.stateDir}/models";
        VOICES_DIR = "${kokoro-fastapi}/share/kokoro-fastapi/api/src/voices/v1_0";
        OUTPUT_DIR = "${cfg.stateDir}/output";
        TEMP_FILE_DIR = "${cfg.stateDir}/temp";
        WEB_PLAYER_PATH = "${kokoro-fastapi}/share/kokoro-fastapi/web";
        ENABLE_WEB_PLAYER = if cfg.enableWebPlayer then "true" else "false";

        # ROCm / GPU tuning
        HSA_OVERRIDE_GFX_VERSION = "9.0.6";  # MI50 = gfx906
        TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL = "1";
        MIOPEN_FIND_MODE = "2";  # Reuse on-disk find DB

        # MIOpen cache location (HOME-relative)
        HOME = cfg.stateDir;

        # espeak paths
        PHONEMIZER_ESPEAK_PATH = "${pkgs.espeak-ng}/bin";
        PHONEMIZER_ESPEAK_DATA = "${pkgs.espeak-ng}/share/espeak-ng-data";
        ESPEAK_DATA_PATH = "${pkgs.espeak-ng}/share/espeak-ng-data";
      };

      serviceConfig = {
        Type = "simple";
        User = "kokoro";
        Group = "kokoro";
        ExecStart = "${kokoro-fastapi}/bin/kokoro-fastapi";
        Restart = "on-failure";
        RestartSec = "5s";

        # GPU access
        SupplementaryGroups = [ "render" "video" ];

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "full";
        ProtectHome = true;
        PrivateTmp = false;
        ReadWritePaths = [ cfg.stateDir ];
        StateDirectory = "kokoro";
        StateDirectoryMode = "0750";
      };
    };

    # Ensure writable directories exist
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir}/models 0750 kokoro kokoro -"
      "d ${cfg.stateDir}/output 0750 kokoro kokoro -"
      "d ${cfg.stateDir}/temp 0750 kokoro kokoro -"
      "d ${cfg.stateDir}/.config/miopen 0750 kokoro kokoro -"
      "d ${cfg.stateDir}/.cache/miopen 0750 kokoro kokoro -"
    ];

    # Firewall
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
