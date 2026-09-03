# droid's user environment: the android linux terminal guest on the phone.
#
# left out of the meatwizard set on purpose: aws, clownops, kube and obs are
# work infrastructure that is not reachable from the phone, fonts and zed are
# gui concerns, and sops wants an age key this guest does not hold yet
{
  imports = [
    ./fish.nix
    ./git.nix
    ./neovim.nix
    ./nix-tools.nix
    ./ssh.nix
    ./starship.nix
    ./television.nix
    ./tmux.nix
    ./uv.nix
  ];

  home.stateVersion = "26.11";
}
