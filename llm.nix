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
              # https://github.com/NixOS/nixpkgs/issues/420638#issuecomment-3015134430
              "--cdi-spec-dir=/run/cdi"
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
              "--cdi-spec-dir=/run/cdi"
              "--device" "nvidia.com/gpu=all"
              "--ipc" "host"
              # "--pull=newer"
              "-v" "${constants.models_dir}:/cache"
              "--network=host"
            ];
            cmd = [
              "--model" "Qwen/Qwen3-Embedding-0.6B"
              # "--max-model-len" "32768"
              "--max-model-len" "10000"
              "--gpu-memory-utilization" "0.1"
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
              "--cdi-spec-dir=/run/cdi"
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
      systemd.services.vllm-qwen3.serviceConfig = {
        Restart = "always";
        User = constants.myuser;
      };
      systemd.services.vllm-qwen3-embed.unitConfig = {
        ConditionPathExists = constants.models_dir;
      };
      systemd.services.vllm-qwen3-embed.serviceConfig = {
        Restart = "always";
        User = constants.myuser;
      };
      systemd.services.vllm-mimo-vl.unitConfig = {
        ConditionPathExists = constants.models_dir;
      };
      systemd.services.vllm-mimo-vl.serviceConfig = {
        Restart = "always";
        User = constants.myuser;
      };
      systemd.services.llamacpp_llm_service = {
        enable = true;
        description = "service for llama-cpp";
        environment = {
          "LLAMA_CACHE" = constants.models_dir;
        };
        wantedBy = [ "multi-user.target" ];
        script = ''
          ${config.machine.llama-cpp.pkg}/bin/llama-server\
            -hf unsloth/Qwen3-30B-A3B-Thinking-2507-GGUF:Q4_K_M\
            --jinja -ngl 99 --threads 16 --ctx-size 100000 -fa\
            --temp 0.6 --min-p 0.0 --top-p 0.95 --top-k 20 --presence-penalty 1.4\
            --port 5000 --host 0.0.0.0 --seed 2 --cache-type-k q8_0 --cache-type-v q8_0
        '';
        # script = ''
        #   ${config.machine.llama-cpp.pkg}/bin/llama-server\
        #     -hf unsloth/Qwen3-30B-A3B-Thinking-2507-GGUF:Q5_K_XL\
        #     --jinja -ngl 99 --threads 16 --ctx-size $((2 ** 18)) -fa\
        #     --temp 0.6 --min-p 0.0 --top-p 0.95 --top-k 20 --presence-penalty 1.4\
        #     --no-kv-offload --port 5000 --host 0.0.0.0 --seed 2
        # '';
        # script = ''
        #   ${config.machine.llama-cpp.pkg}/bin/llama-server\
        #     -hf unsloth/Seed-OSS-36B-Instruct-GGUF:Q4_K_M\
        #     --jinja -ngl 99 --threads 16 --ctx-size $((2 ** 18)) --flash-attn\
        #     --temp 1.1 --min-p 0.0 --top-p 0.95 --top-k 20 --presence-penalty 1.4\
        #     --no-kv-offload --port 5000 --host 0.0.0.0 --seed 2\
        #     --cache-type-k q8_0 --cache-type-v q8_0\
        #     --chat-template-kwargs '{"thinking_budget": 1024}'
        # '';
        # script = ''
        #   ${config.machine.llama-cpp.pkg}/bin/llama-server\
        #     --host 0.0.0.0\
        #     --port 5000\
        #     -hf bartowski/zai-org_GLM-4.5-Air-GGUF:Q3_K_M\
        #     --jinja\
        #     -ngl 99\
        #     -fa\
        #     --temp 0.7\
        #     --top-k 20\
        #     --top-p 0.95\
        #     --min-p 0\
        #     --presence-penalty 1.4\
        #     --seed 2\
        #     --no-kv-offload\
        #     --cache-type-k q8_0\
        #     --cache-type-v q8_0\
        #     --override-tensor "\.(1[7-9]|[2-9][0-9]|[1-9][0-9]{2})\.ffn_.*_exps.=CPU"\
        #     -c 60000\
        #     --threads 25
        # '';
        # script = ''
        #   ${config.machine.llama-cpp.pkg}/bin/llama-server\
        #     --host 0.0.0.0\
        #     --port 5000\
        #     -hf bullerwins/Hunyuan-A13B-Instruct-GGUF:Q4_K_M\
        #     --jinja\
        #     -ngl 99\
        #     -fa\
        #     --temp 0.7\
        #     --top-k 20\
        #     --top-p 0.95\
        #     --min-p 0\
        #     --presence-penalty 1.4\
        #     --seed 2\
        #     --no-kv-offload\
        #     --cache-type-k q8_0\
        #     --cache-type-v q8_0\
        #     --override-tensor "\.(1[3-9]|[2-9][0-9]|[1-9][0-9]{2})\.ffn_.*_exps.=CPU"\
        #     -c 260000\
        #     --threads 25
        # '';
        serviceConfig = {
          Restart = "always";
          User = constants.myuser;
        };
        unitConfig = {
          ConditionPathExists = constants.models_dir;
        };
      };
      systemd.services.llamacpp_embed_service = {
        enable = false;
        description = "service for embeddings generation through llama-cpp";
        environment = {
          "LLAMA_CACHE" = constants.models_dir;
        };
        wantedBy = [ "multi-user.target" ];
        script = "${config.machine.llama-cpp.pkg}/bin/llama-server --host 0.0.0.0 --port 5001 -hf unsloth/Qwen3-0.6B-GGUF:Q4_K_M -ngl 99 -fa -c 16000 --seed 2 --embedding --pooling last -ub 8000 --no-kv-offload";
        serviceConfig = {
          Restart = "always";
          User = constants.myuser;
        };
        unitConfig = {
          ConditionPathExists = constants.models_dir;
        };
      };
    })
    {
      virtualisation.oci-containers = {
        containers = {
          # lobe-chat = {
          #   image = "docker.io/lobehub/lobe-chat:latest";
          #   environment = {
          #     "OPENAI_PROXY_URL" = "http://mahmooz2:5000";
          #   };
          #   extraOptions = [
          #     "--network=host"
          #     "--name=lobe-chat"
          #     "-v" "${constants.home_dir}/.lobe-chat:/app/backend/data"
          #   ];
          # };
        };
      };
    }
  ];
}