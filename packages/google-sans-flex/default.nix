{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "google-sans-flex";
  version = "4.007";

  src = fetchzip {
    url = "https://github.com/googlefonts/googlesans-flex/releases/download/v${finalAttrs.version}/GoogleSansFlex-v${finalAttrs.version}.zip";
    hash = "sha256-o3P0Tmz53iRwQlx3T7VOwxyWZ1EggQuVeXn13w+YClg=";
    stripRoot = false;
  };

  installPhase = ''
    runHook preInstall
    install -Dm444 -t "$out/share/fonts/truetype" *.ttf
    runHook postInstall
  '';

  meta = {
    description = "Google Sans Flex variable font";
    homepage = "https://github.com/googlefonts/googlesans-flex";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
})
