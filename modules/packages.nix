{ pkgs, inputs, ... }:

let
  groups = import ../lib/packages.nix { inherit pkgs; };

  lock-screen = pkgs.stdenv.mkDerivation {
    name = "lock-screen";
    dontUnpack = true;
    buildPhase = ''
            cat << "EOF" > main.c
      #include <dlfcn.h>
      int main(void) {
        void *h = dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_LAZY);
        if (!h) return 1;
        int (*lock)(void) = dlsym(h, "SACLockScreenImmediate");
        if (!lock) return 1;
        return lock();
      }
      EOF
            $CC -O2 main.c -o lock-screen
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp lock-screen $out/bin/
    '';
  };

  ghostty-new = pkgs.writeShellScriptBin "ghostty-new" ''
    if /usr/bin/osascript -e 'if application "Ghostty" is running then
      with timeout of 2 seconds
        tell application "Ghostty" to new window with configuration {initial working directory:"'"$HOME"'"}
      end timeout
    else
      error "not running"
    end if' >/dev/null 2>&1; then
      exit 0
    fi
    exec open -na Ghostty
  '';

  finder-new = pkgs.writeShellScriptBin "finder-new" ''
    exec /usr/bin/osascript -e 'tell application "Finder"
      set w to make new Finder window
      set target of w to path to home folder
      activate
    end tell' >/dev/null
  '';

  # hey-cli publishes darwin artifacts only, so it cannot live in lib/packages.nix
  # without breaking rubicon's eval
  macos = [
    pkgs.ardour
    pkgs.ghidra
    pkgs.hey-cli
    pkgs.macmon
    inputs.ratatouille.packages.${pkgs.stdenv.hostPlatform.system}.default
    lock-screen
    ghostty-new
    finder-new
  ];

  toys = [
    inputs.tart.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.waves.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
in
{
  environment.systemPackages =
    groups.shell
    ++ groups.vcs
    ++ groups.editors
    ++ groups.agents
    ++ groups.languages
    ++ groups.infra
    ++ groups.kubernetes
    ++ groups.nixTooling
    ++ groups.fontTooling
    ++ groups.browsers
    ++ macos
    ++ toys;
}
