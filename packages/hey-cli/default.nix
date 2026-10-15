{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
}:

let
  version = "1.4.1";

  artifacts = {
    aarch64-darwin = {
      platform = "darwin_arm64";
      hash = "sha256-4C2WA5KQJDNJ2xBqA/FSS+MTM3HfBK1xNP4P6FeB4ZA=";
    };
    x86_64-darwin = {
      platform = "darwin_amd64";
      hash = "sha256-288HPs0mZ7W180Xk/L9uQUcoB6DGh8QItzBkr66hIAE=";
    };
  };

  inherit (stdenvNoCC.hostPlatform) system;

  artifact = artifacts.${system} or (throw "hey-cli has no published artifact for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "hey-cli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/basecamp/hey-cli/releases/download/v${version}/hey_${version}_${artifact.platform}.tar.gz";
    inherit (artifact) hash;
  };

  nativeBuildInputs = [ installShellFiles ];

  sourceRoot = ".";

  dontStrip = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 hey "$out/bin/hey"
    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    installShellCompletion --cmd hey \
      --bash <("$out/bin/hey" completion bash) \
      --fish <("$out/bin/hey" completion fish) \
      --zsh <("$out/bin/hey" completion zsh)
  '';

  meta = {
    description = "HEY email from the terminal";
    homepage = "https://github.com/basecamp/hey-cli";
    license = lib.licenses.mit;
    platforms = builtins.attrNames artifacts;
    mainProgram = "hey";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
