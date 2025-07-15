{ config, pkgs, ... }:

let
  khojDataRoot = "/home/mahmooz/.khoj/";
in
{
  project.name = "mykhoj";

  services = {
    # The khoj-computer service
    "khoj-computer" = {
      image.enableRecommendedContents = true;
      service.useHostStore = true;
      service.image = "ghcr.io/khoj-ai/khoj-computer:latest";
      service.network_mode = "host";
      service.ports = [ "5900:5900" ];
      service.volumes = [ "${khojDataRoot}/computer:/home/operator" ];
    };

    database = {
      image.enableRecommendedContents = true;
      service.useHostStore = true;
      service.image = "docker.io/pgvector/pgvector:pg15";
      service.network_mode = "host";
      service.ports = [ "5432:5432" ];
      service.environment = {
        POSTGRES_DB = "postgres";
        POSTGRES_PASSWORD = "postgres";
        POSTGRES_USER = "postgres";
      };
      service.volumes = [ "${khojDataRoot}/db:/var/lib/postgresql/data" ];
      service.healthcheck = {
        test = [ "CMD" "pg_isready" "-U" "postgres" ];
        interval = "30s";
        timeout = "10s";
        retries = 5;
      };
    };

    # sandbox = {
    #   image.enableRecommendedContents = true;
    #   service.useHostStore = true;
    #   service.image = "ghcr.io/khoj-ai/terrarium:latest";
    #   service.network_mode = "host";
    #   service.ports = [ "8081:8081" ];
    #   service.healthcheck = {
    #     test = [ "CMD" "curl" "-f" "http://localhost:8081/health" ];
    #     interval = "30s";
    #     timeout = "10s";
    #     retries = 2;
    #   };
    # };

    # search = {
    #   image.enableRecommendedContents = true;
    #   service.useHostStore = true;
    #   service.image = "docker.io/searxng/searxng:latest";
    #   service.network_mode = "host";
    #   service.ports = [ "8082:8082" ];
    #   service.environment = {
    #     "SEARXNG_PORT" = "8082";
    #     "SEARXNG_BASE_URL" = "http://localhost:8082/";
    #   };
    #   service.volumes = [ "${khojDataRoot}/search:/etc/searxng" ];
    # };

    server = {
      image.enableRecommendedContents = true;
      service.useHostStore = true;
      service.image = "ghcr.io/khoj-ai/khoj:latest";
      service.network_mode = "host";
      service.ports = [ "42110:42110" ];
      service.command = [ "--host=0.0.0.0" "--port=42110" "-vv" "--anonymous-mode" "--non-interactive" ];
      service.depends_on = [ "database" ];
      service.environment = {
        FIRECRAWL_API_KEY = builtins.getEnv "FIRECRAWL_API_KEY";
        KHOJ_ADMIN_EMAIL = "username@example.com";
        KHOJ_ADMIN_PASSWORD = "password";
        KHOJ_DEBUG = "True";
        KHOJ_DEFAULT_CHAT_MODEL = "qwen3";
        KHOJ_DJANGO_SECRET_KEY = "secret";
        # KHOJ_OPERATOR_ENABLED = "True";
        # KHOJ_SEARXNG_URL = "http://localhost:8082";
        # KHOJ_TERRARIUM_URL = "http://localhost:8081";
        OPENAI_BASE_URL = "http://mahmooz2:5000/v1/";
        POSTGRES_DB = "postgres";
        POSTGRES_HOST = "localhost";
        POSTGRES_PASSWORD = "postgres";
        POSTGRES_PORT = "5432";
        POSTGRES_USER = "postgres";
        KHOJ_TELEMETRY_DISABLE = "True";
      };
      service.volumes = [
        "/var/run/docker.sock:/var/run/docker.sock"
        "${khojDataRoot}/config:/root/.khoj"
        "${khojDataRoot}/models:/root/.cache/huggingface"
      ];
      service.extra_hosts = [ "host.docker.internal:host-gateway" ];
      service.working_dir = "/app";
    };
  };
}