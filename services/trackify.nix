{ config, pkgs, lib, inputs, ... }:

let
  constants = import ../lib/constants.nix;
in
{
  imports = [ inputs.trackify.nixosModules.default ];

  services.trackify = {
    domain = "trackify.${constants.mydomain}";
    secretKey = builtins.getEnv "TRACKIFY_SECRET_KEY";
    spotify.clientId = builtins.getEnv "TRACKIFY_SPOTIFY_CLIENT_ID";
    spotify.clientSecret = builtins.getEnv "TRACKIFY_SPOTIFY_CLIENT_SECRET";
    discogs.apiKey = builtins.getEnv "TRACKIFY_DISCOGS_API_KEY";
    discogs.apiSecret = builtins.getEnv "TRACKIFY_DISCOGS_API_SECRET";
  };
}
