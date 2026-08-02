{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
}:

let
  version = "0.2.118";

  artifacts = {
    aarch64-darwin = {
      platform = "macos-aarch64";
      hash = "sha256-LeW5YJoDSS3WueTMqWN9ZR/pmLuDcb+fhS57KLOMA04=";
    };
    x86_64-darwin = {
      platform = "macos-x86_64";
      hash = "sha256-kxg8+wct+Iy6xwfkT4u8YtlHTSBH6chgVRnGS3IOJok=";
    };
  };

  inherit (stdenvNoCC.hostPlatform) system;

  artifact = artifacts.${system} or (throw "grok has no published artifact for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "grok";
  inherit version;

  src = fetchurl {
    url = "https://storage.googleapis.com/grok-build-public-artifacts/cli/grok-${version}-${artifact.platform}";
    inherit (artifact) hash;
  };

  nativeBuildInputs = [ installShellFiles ];

  dontUnpack = true;

  # xai ships it signed with the hardened runtime, so leave the mach-o alone
  dontStrip = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/grok"
    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    installShellCompletion --cmd grok \
      --bash <("$out/bin/grok" completions bash) \
      --fish <("$out/bin/grok" completions fish) \
      --zsh <("$out/bin/grok" completions zsh)
  '';

  meta = {
    description = "Grok Build, the xAI coding agent CLI";
    homepage = "https://github.com/xai-org/grok-build";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "grok";
    platforms = lib.attrNames artifacts;
  };
}
