{
  lib,
  stdenvNoCC,
  geist-font,
  nerd-font-patcher,
}:

stdenvNoCC.mkDerivation {
  pname = "geist-mono-nerd-font";
  inherit (geist-font) version;

  dontUnpack = true;

  nativeBuildInputs = [ nerd-font-patcher ];

  buildPhase = ''
    runHook preBuild

    mkdir patched
    for style in Regular Italic Bold BoldItalic; do
      nerd-font-patcher \
        --complete \
        --careful \
        --mono \
        --no-progressbars \
        --outputdir patched \
        --quiet \
        "${geist-font}/share/fonts/opentype/GeistMono-$style.otf"
    done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -d "$out/share/fonts/opentype"
    install -m444 patched/*.otf "$out/share/fonts/opentype/"

    runHook postInstall
  '';

  meta = {
    description = "Geist Mono patched with Nerd Fonts glyphs";
    homepage = "https://vercel.com/font";
    license = with lib.licenses; [
      mit
      ofl
    ];
    platforms = lib.platforms.all;
  };
}
