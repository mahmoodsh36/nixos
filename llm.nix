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
          autoStart = true;
          image = "vllm/vllm-openai:latest";
          extraOptions = [
            "--gpus" "all"
            "--ipc" "host"
            "-v" "${constants.models_dir}:/cache"
            "--network=host"
          ];
          cmd = [
            "--model" "XiaomiMiMo/MiMo-VL-7B-RL"
            "--max-model-len" "27000"
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
  };
}