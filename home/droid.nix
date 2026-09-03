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
  # corrects it, so tmux and nvim's :terminal would open bash inside fish.
  # the greeting is two lines of a ~50 column phone screen, so it goes
  programs.fish.interactiveShellInit = ''
    set -gx SHELL (status fish-path)
    set -g fish_greeting ""
  '';

  # the terminal app shows the window title as the tab label: the running
  # command while it runs, the directory while idle
  programs.fish.functions = {
    __title_preexec = {
      onEvent = "fish_preexec";
      body = ''printf "\033]0;%s\007" (string sub -l 40 -- $argv[1])'';
    };
    __title_prompt = {
      onEvent = "fish_prompt";
      body = ''printf "\033]0;%s\007" (prompt_pwd)'';
    };
  };
}
