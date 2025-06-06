{ config, pkgs, lib, inputs, pkgs-pinned, ... }:

let
  constants = (import ./constants.nix);
in
{
  config = lib.mkIf config.machine.enable_nvidia {
    virtualisation.oci-containers = {
      backend = "podman";
      containers = {
        vllm = {
          autoStart = true;
          image = "vllm/vllm-openai:latest";
          extraOptions = [
            "--runtime" "nvidia"
            "--gpus" "all"
            "--ipc" "host"
            "--pull=always"
            "-v ${constants.models_dir}:/cache"
            "--network=host"
          ];
          cmd = [
            "--model" "Qwen/Qwen3-14B"
            "--max-model-len" "$((2 ** 16))"
            "--gpu-memory-utilization" "0.9"
            "--enable-reasoning"
            "--quantization" "bitsandbytes"
            "--enable-auto-tool-choice"
            "--tool-call-parser" "hermes"
            "--download-dir" "/cache"
            "--host" "0.0.0.0"
            "--port" "5000"
          ];
        };
      };
    };
  };
}