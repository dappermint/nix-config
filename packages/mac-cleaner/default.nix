{
  lib,
  buildGoModule,
}:

buildGoModule rec {
  pname = "mac-cleaner";
  version = "0.1.0";

  src = ./.;
  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  postInstall = ''
    install -Dm644 README.md "$out/share/doc/mac-cleaner/README.md"
  '';

  meta = {
    description = "Preview-first macOS storage cleanup TUI";
    mainProgram = "mac-cleaner";
    platforms = lib.platforms.darwin;
  };
}
