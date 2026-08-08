rec {
  # the checkout, which is still where the lock gets bumped and secrets get
  # edited: nix cannot write a lock file into a remote flake
  directory = "/etc/nix-darwin";
  secretsFile = "${directory}/secrets/secrets.yaml";

  # what the system is actually built from. private, so every fetch needs an
  # access token
  flake = "github:dappermint/nix-config";
}
