{ config, pkgs, ... }:

let
  constants = (import ./constants.nix);
in
{
  project.name = "open-notebook";

  services = {
    surrealdb = {
      image.enableRecommendedContents = true;
      service.useHostStore = true;
      service.image = "surrealdb/surrealdb:v2";
      service.ports = [ "8000:8003" ];
      service.command = [
        "start"
        "--user" "root"
        "--pass" "root"
        "rocksdb:/mydata/mydatabase.db"
      ];
      service.volumes = [ "${constants.home_dir}/.surrealdb:/mydata" ];
      service.user = "root";
    };

    open_notebook = {
      image.enableRecommendedContents = true;
      service.useHostStore = true;
      service.image = "lfnovo/open_notebook:latest";
      service.ports = [ "8080:8502" ];
      service.depends_on = [ "surrealdb" ];
      service.environment = {
        # OPENAI_API_KEY = builtins.getEnv "OPENAI_API_KEY";
        OPENAI_API_KEY = builtins.getEnv "none";
        SURREAL_ADDRESS = "surrealdb";
        SURREAL_PORT = "8003";
        SURREAL_USER = "root";
        SURREAL_PASS = "root";
        SURREAL_NAMESPACE = "open_notebook";
        SURREAL_DATABASE = "open_notebook";
      };
      service.volumes = [ "${constants.home_dir}/.notebook_data:/app/data" ];
    };
  };
}