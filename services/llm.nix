{ config, pkgs, lib, system, ... }:

let
  cfg = config.llms;
  llamaPkg = if cfg.llama-cpp.package != null
             then cfg.llama-cpp.package
             else pkgs.llama-cpp;
  isDarwin = builtins.match ".*-darwin" system != null;
  isLinux = builtins.match ".*-linux" system != null;
in
{
  options.llms = {
    enable = lib.mkEnableOption "LLM services module";

    modelsDirectory = lib.mkOption {
      type = lib.types.str;
      description = "Absolute path to the directory for LLM models.";
    };

    llama-cpp = {
      enable = lib.mkEnableOption "the llama.cpp server";
      # allow null here so we don't reference `pkgs` at import time
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        defaultText = "null (falls back to pkgs.llama-cpp)";
        description = "The llama.cpp package to use for the server. Leave null to use pkgs.llama-cpp.";
      };
    };

    lobe-chat = {
      enable = lib.mkEnableOption "the Lobe Chat UI container";
    };
  };

  config = {} // (if isDarwin then {
    launchd.agents.llamacpp_llm_service = lib.mkIf cfg.llama-cpp.enable {
      command = pkgs.writeShellScript "start-llama-server.sh" ''
        #!${pkgs.stdenv.shell}
        export LLAMA_CACHE="${cfg.modelsDirectory}"
        exec ${llamaPkg}/bin/llama-server \
          -hf Qwen/Qwen3-VL-30B-A3B-Thinking-GGUF:Q4_K_M \
          --jinja -ngl 99 --threads 16 --ctx-size 100000 -fa on \
          --temp 0.6 --min-p 0.0 --top-p 0.95 --top-k 20 --presence-penalty 1.4 \
          --port 5000 --host 0.0.0.0 --seed 2 \
          --cache-type-k q8_0 --cache-type-v q8_0
      '';

      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/tmp/llamacpp_llm_service.log";
        StandardErrorPath = "/tmp/llamacpp_llm_service.log";
      };
    };
  } else {}) // (if isLinux then {
    systemd.services.llamacpp_llm_service = lib.mkIf cfg.llama-cpp.enable {
      description = "llama.cpp GGUF model serving";
      wantedBy = [ "multi-user.target" ];

      script = pkgs.writeShellScript "start-llama-server.sh" ''
          #!${pkgs.stdenv.shell}
          export LLAMA_CACHE="${cfg.modelsDirectory}"
          exec ${llamaPkg}/bin/llama-server \
            -hf unsloth/Qwen3-4B-Thinking-2S-GGUF:Q8_0 \
            --jinja -ngl 99 --threads 16 --ctx-size 200000 -fa on \
            --temp 0.6 --min-p 0.0 --top-p 0.95 --top-k 20 --presence-penalty 1.4 \
            --port 5000 --host 0.0.0.0 --seed 2 \
            --cache-type-k q8_0 --cache-type-v q8_0
        '';

      serviceConfig = {
        Restart = "always";
      };
      unitConfig.ConditionPathExists = cfg.modelsDirectory;
    };
  } else {});
}