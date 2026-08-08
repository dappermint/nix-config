{
  imports = [
    ./aws.nix
    ./clownops.nix
    ./fish.nix
    ./fonts.nix
    ./git.nix
    ./kube.nix
    ./nix-tools.nix
    ./obs.nix
    ./sops.nix
    ./ssh.nix
    ./zed.nix
  ];

  home.stateVersion = "26.11";
}
