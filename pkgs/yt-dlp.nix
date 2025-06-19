{ pkgs ? import <nixpkgs> {} }:

pkgs.yt-dlp.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.perl ];
  patchPhase = ''
    echo doing here ==
    cat yt_dlp/extractor/unsupported.py
    perl -0777 -i -pe 's/^[ \t]*URLS = \((?!\))(.|\n)*?^[ \t]*\)/    URLS = ()\n/msg' yt_dlp/extractor/unsupported.py
    cat yt_dlp/extractor/unsupported.py
    echo doing here2 ==
    ${old.patchPhase or ""}
  '';
})