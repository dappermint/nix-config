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

  # the terminal app never logs in: ttyd_uds.service runs
  # `setpriv --reuid=droid ... /bin/bash -l` hardcoded and exports
  # SHELL=/bin/bash, so it never reads the login shell out of /etc/passwd and
  # chsh cannot change what a tab opens. patching that unit would work until
  # the next re-provision reverts everything outside /home/droid, so the hop
  # to fish lives in $HOME instead
  home.file.".bash_profile".text = ''
    [ -f "$HOME/.profile" ] && . "$HOME/.profile"

    # interactive login shells only, so `bash -lc ...` and a rescue shell are
    # left alone. NO_FISH=1 stays in bash for a session
    case $- in
      *i*)
        if [ -z "$NO_FISH" ] && [ -x "$HOME/.nix-profile/bin/fish" ]; then
          exec "$HOME/.nix-profile/bin/fish" --login
        fi
        ;;
    esac
  '';

  # ttyd exports SHELL=/bin/bash into the session it spawns, and nothing later
  # corrects it, so tmux and nvim's :terminal would open bash inside fish
  programs.fish.interactiveShellInit = ''
    set -gx SHELL (status fish-path)
  '';
}
