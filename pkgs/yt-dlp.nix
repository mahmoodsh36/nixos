{ pkgs }:

pkgs.python3Packages.yt-dlp.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.perl ];

  # src = pkgs.fetchFromGitHub {
  #   owner = "yt-dlp";
  #   repo = "yt-dlp";
  #   rev = "73bf10211668e4a59ccafd790e06ee82d9fea9ea";
  #   sha256 = "07kkrmbld6jsknyyf3b171njdmh73xfjf86k6fl5zd30bma1fbiw";
  # };

  # to remove the blocked urls
  patchPhase = ''
    ${old.patchPhase or ""}
    perl -0777 -i -pe 's/^[ \t]*URLS = \((?!\))(.|\n)*?^[ \t]*\)/    URLS = ()\n/msg' yt_dlp/extractor/unsupported.py
    perl -0777 -i -pe 's/^([ \t]*)_TESTS = \[\{(?:.|\n)*?\}\][ \t]*\n/''${1}_TESTS = []\n/msg' yt_dlp/extractor/unsupported.py
  '';
})