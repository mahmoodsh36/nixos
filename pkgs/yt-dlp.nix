{ yt-dlp, perl }:

yt-dlp.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ perl ];

  patchPhase = ''
    ${old.patchPhase or ""}
    perl -0777 -i -pe 's/^[ \t]*URLS = \((?!\))(.|\n)*?^[ \t]*\)/    URLS = ()\n/msg' yt_dlp/extractor/unsupported.py
  '';
})
