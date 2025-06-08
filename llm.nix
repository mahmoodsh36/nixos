{ config, pkgs, lib, inputs, pkgs-pinned, ... }:

let
  constants = (import ./constants.nix);
in
{
  config = lib.mkIf config.machine.enable_nvidia {
    virtualisation.oci-containers = {
      backend = "podman";
      containers = {
        vllm-qwen3 = {
          autoStart = false;
          image = "vllm/vllm-openai:latest";
          extraOptions = [
            "--gpus" "all"
            "--ipc" "host"
            # "--pull=always"
            "-v" "${constants.models_dir}:/cache"
            "--network=host"
          ];
          cmd = [
            "--model" "Qwen/Qwen3-14B"
            # "--max-model-len" "65536"
            "--max-model-len" "32768"
            "--gpu-memory-utilization" "0.9"
            "--enable-reasoning"
            "--quantization" "bitsandbytes"
            "--enable-auto-tool-choice"
            "--tool-call-parser" "hermes"
            "--download-dir" "/cache"
            # "--rope-scaling" ''{"rope_type":"yarn","factor":2.0,"original_max_position_embeddings":32768}''
            "--seed" "2"
            "--host" "0.0.0.0"
            "--port" "5000"
          ];
        };
        vllm-qwen3-embed = {
          autoStart = true;
          image = "vllm/vllm-openai:latest";
          extraOptions = [
            "--gpus" "all"
            "--ipc" "host"
            # "--pull=always"
            "-v" "${constants.models_dir}:/cache"
            "--network=host"
          ];
          cmd = [
            "--model" "Qwen/Qwen3-Embedding-0.6B"
            "--max-model-len" "32768"
            # "--gpu-memory-utilization" "0.9" # default
            "--quantization" "bitsandbytes"
            "--download-dir" "/cache"
            "--seed" "2"
            "--task" "embedding"
            "--host" "0.0.0.0"
            "--port" "5001"
          ];
        };
        vllm-mimo-vl = {
          autoStart = false;
          image = "vllm/vllm-openai:latest";
          extraOptions = [
            "--gpus" "all"
            "--ipc" "host"
            "-v" "${constants.models_dir}:/cache"
            "--network=host"
          ];
          cmd = [
            "--model" "XiaomiMiMo/MiMo-VL-7B-RL"
            "--max-model-len" "24000"
            "--gpu-memory-utilization" "1"
            "--enable-reasoning"
            "--enable-auto-tool-choice"
            "--tool-call-parser" "hermes"
            "--download-dir" "/cache"
            "--seed" "2"
            "--host" "0.0.0.0"
            "--port" "5000"
          ];
        };
      };
    };
    systemd.services.vllm-qwen3.unitConfig = {
      ConditionPathExists = constants.models_dir;
    };
    systemd.services.vllm-qwen3-embed.unitConfig = {
      ConditionPathExists = constants.models_dir;
    };
    systemd.services.vllm-mimo-vl.unitConfig = {
      ConditionPathExists = constants.models_dir;
    };
    systemd.services.llamacpp_service = {
      description = "service for llama-cpp";
      environment = {
        "LLAMA_CACHE" = constants.models_dir;
      };
      wantedBy = [ "multi-user.target" ];
      script = "${inputs.llama-cpp-flake.packages.${pkgs.system}.cuda}/bin/llama-server --host 0.0.0.0 --port 5000 -m ${constants.model_dir}/final-Qwen--Qwen3-14B.gguf --jinja -ngl 99 -fa --temp 0.6 --top-k 20 --top-p 0.95 --min-p 0 --presence-penalty 1.5 -c 85000 --seed 2";
      serviceConfig = {
        Restart = "always";
        ConditionPathExists = constants.models_dir;
      };
    };
  };
}