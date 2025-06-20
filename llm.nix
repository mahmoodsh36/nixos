{ config, pkgs, lib, inputs, pkgs-pinned, ... }:

let
  constants = (import ./constants.nix);
in
{
  config = lib.mkMerge [
    (lib.mkIf config.machine.enable_nvidia {
      virtualisation.oci-containers = {
        backend = "podman";
        containers = {
          vllm-qwen3 = {
            autoStart = false;
            image = "vllm/vllm-openai:latest";
            extraOptions = [
              # "--gpus" "all"
              "--device" "nvidia.com/gpu=all"
              "--ipc" "host"
              # "--pull=newer"
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
            autoStart = false;
            image = "vllm/vllm-openai:latest";
            extraOptions = [
              # "--gpus" "all"
              "--device" "nvidia.com/gpu=all"
              "--ipc" "host"
              # "--pull=newer"
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
              # "--gpus" "all"
              "--device" "nvidia.com/gpu=all"
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
      systemd.services.llamacpp_llm_service = {
        enable = true;
        description = "service for llama-cpp";
        environment = {
          "LLAMA_CACHE" = constants.models_dir;
        };
        wantedBy = [ "multi-user.target" ];
        # script = "${inputs.llama-cpp-flake.packages.${pkgs.system}.cuda}/bin/llama-server --host 0.0.0.0 --port 5000 -m ${constants.models_dir}/final-Qwen--Qwen3-32B.gguf --jinja -ngl 99 -fa --temp 0.7 --top-k 20 --top-p 0.95 --min-p 0 --presence-penalty 1.4 -c 20000 --seed 2 --cache-type-k q8_0 --cache-type-v q8_0 --reasoning-format deepseek";
        # script = "${inputs.llama-cpp-flake.packages.${pkgs.system}.cuda}/bin/llama-server --host 0.0.0.0 --port 5000 -hf unsloth/Qwen3-32B-GGUF:Q4_K_M --jinja -ngl 99 -fa --temp 0.7 --top-k 20 --top-p 0.95 --min-p 0 --presence-penalty 1.4 -c 20000 --seed 2 --cache-type-k q8_0 --cache-type-v q8_0 --reasoning-format deepseek";
        # script = "${inputs.llama-cpp-flake.packages.${pkgs.system}.cuda}/bin/llama-server --host 0.0.0.0 --port 5000 -hf unsloth/Magistral-Small-2506-GGUF:UD-Q4_K_XL --jinja --temp 0.7 --top-k 20 -ngl 99 -fa --top-p 0.95 -c 30000 --seed 2 --cache-type-k q8_0 --cache-type-v q8_0";
        script = "${inputs.llama-cpp-flake.packages.${pkgs.system}.cuda}/bin/llama-server --host 0.0.0.0 --port 5000 -hf Qwen/Qwen3-14B-GGUF:Q4_K_M --jinja -ngl 99 -fa --temp 0.6 --top-k 20 --top-p 0.95 --min-p 0 --presence-penalty 1.4 -c 70000 --seed 2";
        # script = "${inputs.llama-cpp-flake.packages.${pkgs.system}.cuda}/bin/llama-server --host 0.0.0.0 --port 5000 -hf unsloth/Qwen3-30B-A3B-GGUF:Q4_K_M --jinja -ngl 99 -fa --temp 0.7 --top-k 20 --top-p 0.95 --min-p 0 --presence-penalty 1.4 -c 20000 --seed 2 --cache-type-k q8_0 --cache-type-v q8_0 --reasoning-format deepseek";
        serviceConfig = {
          Restart = "always";
        };
        unitConfig = {
          ConditionPathExists = constants.models_dir;
        };
      };
      systemd.services.llamacpp_embed_service = {
        enable = true;
        description = "service for embeddings generation through llama-cpp";
        environment = {
          "LLAMA_CACHE" = constants.models_dir;
        };
        wantedBy = [ "multi-user.target" ];
        script = "${inputs.llama-cpp-flake.packages.${pkgs.system}.cuda}/bin/llama-server --host 0.0.0.0 --port 5001 -hf Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0 -ngl 99 -fa -c 6000 --seed 2 --embedding --pooling last -ub 6000";
        serviceConfig = {
          Restart = "always";
        };
        unitConfig = {
          ConditionPathExists = constants.models_dir;
        };
      };
    })
    {
      virtualisation.oci-containers = {
        containers = {
          open-webui = {
            autoStart = false;
            image = "ghcr.io/open-webui/open-webui:main";
            extraOptions = [
              "--ipc" "host"
              # "--pull=newer"
              "-v" "${constants.home_dir}/.open-webui:/app/backend/data"
              "--network=host"
              "--name=open-webui"
            ];
            environment = {
              WEBUI_AUTH = "False";
              ANONYMIZED_TELEMETRY = "False";
              DO_NOT_TRACK = "True";
              SCARF_NO_ANALYTICS = "True";
              PORT = "8083";
            };
          };
          # openhands-app = {
          #   autoStart = true;
          #   image = "docker.all-hands.dev/all-hands-ai/openhands:0.34";
          #   ports = [ "3000:3000" ];
          #   # mounts
          #   volumes = [
          #     "/var/run/docker.sock:/var/run/docker.sock"
          #     # persist openhands state
          #     "/home/mahmooz/.openhands-state:/.openhands-state"
          #   ];
          #   environment = {
          #     SANDBOX_RUNTIME_CONTAINER_IMAGE = "docker.all-hands.dev/all-hands-ai/runtime:0.34-nikolaik";
          #     LOG_ALL_EVENTS = "true";
          #   };
          #   extraOptions = [
          #     # "--runtime" "nvidia"
          #     # "--gpus" "all"
          #     "--ipc" "host"
          #     "--pull=always"
          #     "--network=host"
          #   ];
          # };
        };
      };
    }
  ];
}