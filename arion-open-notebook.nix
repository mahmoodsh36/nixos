{ config, pkgs, ... }:

let
  constants = (import ./lib/constants.nix);
in
{
  project.name = "open-notebook";

  services = {
    surrealdb = {
      image.enableRecommendedContents = true;
      service.useHostStore = true;
      service.image = "surrealdb/surrealdb:v2";
      service.ports = [ "8000:8000" ];
      service.command = [
        "start"
        "--user" "root"
        "--pass" "root"
        "rocksdb:/mydata/mydatabase.db"
      ];
      service.volumes = [ "${constants.home_dir}/.surrealdb:/mydata" ];
      service.user = "root";
      service.network_mode = "host";
    };

    open_notebook = {
      image.enableRecommendedContents = true;
      service.useHostStore = true;
      service.image = "lfnovo/open_notebook:latest";
      service.ports = [ "8080:8080" ];
      service.depends_on = [ "surrealdb" ];
      service.environment = {
        # OPENAI_API_KEY = builtins.getEnv "OPENAI_API_KEY";
        OPENAI_API_BASE = "http://mahmooz2:5000/v1";
        OPENAI_API_KEY = "none";
        SURREAL_ADDRESS = "localhost";
        SURREAL_PORT = "8000";
        SURREAL_USER = "root";
        SURREAL_PASS = "root";
        SURREAL_NAMESPACE = "open_notebook";
        SURREAL_DATABASE = "open_notebook";
      };
      service.volumes = [ "${constants.home_dir}/.notebook_data:/app/data" ];
      service.network_mode = "host";
    };
  };
}