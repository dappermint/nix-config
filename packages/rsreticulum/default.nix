{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "rsreticulum";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "ratspeak";
    repo = "rsReticulum";
    rev = "dc6bc4ee82daf66b3b40386f9777dbe62b08fec2";
    hash = "sha256-gdup7PaYOQnBE3Mm4adpjQh5W3DaXWrdmuUhj5cF0ZE=";
  };

  # cargoHash, not cargoLock.lockFile: the lockfile lives inside a fetched
  # src, so reading it needs the src realised, and a pure eval on a fresh
  # clone has no store path to read it from yet
  cargoHash = "sha256-n7r/80mLl/AiBxnkwT7MLQUmNnBNUmNEtwPWBpkT1hQ=";

  cargoBuildFlags = [
    "-p"
    "rns-tools"
  ];
  doCheck = false;

  meta = {
    description = "Rust implementation of the Reticulum network stack (rnsd-rs and tools)";
    homepage = "https://github.com/ratspeak/rsReticulum";
    license = lib.licenses.agpl3Plus;
    mainProgram = "rnsd-rs";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
