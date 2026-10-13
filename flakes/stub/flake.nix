{
  description = "stand-ins for the private inputs, so a clone without access still evaluates";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      eachSystem = fn: nixpkgs.lib.genAttrs systems (system: fn nixpkgs.legacyPackages.${system});

      note = name: "${name} is a private input of this flake and is stubbed out here";
    in
    {
      # the option has to exist or hosts/gotham.nix cannot evaluate, and it has
      # to warn rather than quietly succeed: a silent no-op leaves a house with
      # its home automation switched off
      nixosModules.default =
        { lib, config, ... }:
        {
          options.services.abode.enable = lib.mkEnableOption (note "abode");

          config = lib.mkIf config.services.abode.enable {
            warnings = [ "services.abode.enable is set, but abode is the stub: nothing will run" ];
          };
        };

      # a buildable placeholder, not a throw: this lands in
      # environment.systemPackages, so it has to survive evaluation and only
      # fail if someone actually runs it
      packages = eachSystem (pkgs: {
        default = pkgs.writeShellScriptBin "waves" ''
          echo "${note "waves"}" >&2
          exit 1
        '';
      });
    };
}
