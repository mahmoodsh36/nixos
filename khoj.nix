{ config, pkgs, ... }:

let
  # IMPORTANT: Change this path to a location on your host machine
  # where you want all the persistent data to be stored.
  khojDataRoot = "/home/mahmooz/.khoj/";
in
{
  # This name is used for the project's network and resource prefixes.
  project.name = "mykhoj";

  services = {
    # The khoj-computer service
    "khoj-computer" = {
      image.enableRecommendedContents = true;
      service.useHostStore = true;
      service.image = "ghcr.io/khoj-ai/khoj-computer:latest";
      service.ports = [ "5900:5900" ];
      service.volumes = [ "${khojDataRoot}/computer:/home/operator" ];
    };

    # The PostgreSQL database service
    database = {
      image.enableRecommendedContents = true;
      service.useHostStore = true;
      service.image = "docker.io/pgvector/pgvector:pg15";
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

    # The sandbox service
    sandbox = {
      image.enableRecommendedContents = true;
      service.useHostStore = true;
      service.image = "ghcr.io/khoj-ai/terrarium:latest";
      service.healthcheck = {
        test = [ "CMD" "curl" "-f" "http://localhost:8080/health" ];
        interval = "30s";
        timeout = "10s";
        retries = 2;
      };
    };

    # The SearXNG search service
    search = {
      image.enableRecommendedContents = true;
      service.useHostStore = true;
      service.image = "docker.io/searxng/searxng:latest";
      service.environment = {
        SEARXNG_BASE_URL = "http://localhost:8080/";
      };
      service.volumes = [ "${khojDataRoot}/search:/etc/searxng" ];
    };

    # The main Khoj server application
    server = {
      image.enableRecommendedContents = true;
      service.useHostStore = true;
      service.image = "ghcr.io/khoj-ai/khoj:latest";
      service.ports = [ "42110:42110" ];
      service.command = [ "--host=0.0.0.0" "--port=42110" "-vv" "--anonymous-mode" "--non-interactive" ];
      service.depends_on = [ "database" ];
      service.environment = {
        FIRECRAWL_API_KEY = "your_firecrawl_api_key";
        KHOJ_ADMIN_EMAIL = "username@example.com";
        KHOJ_ADMIN_PASSWORD = "password";
        KHOJ_DEBUG = "False";
        KHOJ_DEFAULT_CHAT_MODEL = "qwen3";
        KHOJ_DJANGO_SECRET_KEY = "secret";
        KHOJ_OPERATOR_ENABLED = "True";
        KHOJ_SEARXNG_URL = "http://search:8080";
        KHOJ_TELEMETRY_DISABLE = "True";
        KHOJ_TERRARIUM_URL = "http://sandbox:8080";
        OPENAI_BASE_URL = "http://host.docker.internal:11434/v1/";
        POSTGRES_DB = "postgres";
        POSTGRES_HOST = "database"; # Arion automatically makes services available by their name
        POSTGRES_PASSWORD = "postgres";
        POSTGRES_PORT = "5432";
        POSTGRES_USER = "postgres";
      };
      service.volumes = [
        # This allows Khoj to interact with the Docker/Podman daemon if needed
        "/var/run/docker.sock:/var/run/docker.sock"
        # Mount local paths for persistent data
        "${khojDataRoot}/config:/root/.khoj"
        "${khojDataRoot}/models:/root/.cache/huggingface"
      ];
      # This is the equivalent of --add-host=host.docker.internal:host-gateway
      service.extra_hosts = [ "host.docker.internal:host-gateway" ];
    };
  };
}