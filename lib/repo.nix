rec {
  # the checkout, which is still where the lock gets bumped and secrets get
  # edited: nix cannot write a lock file into a remote flake
  directory = "/etc/nix-darwin";
  secretsFile = "${directory}/secrets/secrets.yaml";

  # droid keeps its checkout under $HOME instead. the android terminal app
  # re-provisions the guest from a cloud-init seed and a rootfs backup, and
  # everything outside /home/droid is reverted when it does
  linuxCheckout = "Code/nix-config";

  # what the system is actually built from. private, so every fetch needs an
  # access token
  flake = "github:dappermint/nix-config";
}
