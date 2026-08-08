{
  programs.fish.enable = true;

  programs.fish = {
    # shadowing coreutils is only safe because these take the invocations
    # muscle memory produces, and because eza and bat both drop their
    # decorations automatically when they are not writing to a tty, so pipes
    # and redirects behave. `command ls` still reaches the real one.
    #
    # grep, find, sed, rm, cp and mv are deliberately NOT shadowed: rg, fd and
    # sd take incompatible flags, and a pasted command that silently does
    # something else is worse than one that is a little slower
    shellAliases = {
      ls = "eza --group-directories-first";
      ll = "eza -l --group-directories-first --git --header";
      la = "eza -la --group-directories-first --git --header";
      lt = "eza --tree --level=2 --group-directories-first";
      tree = "eza --tree";
      cat = "bat --style=plain";
      top = "btm";
      htop = "btm";
      dig = "doggo";
      traceroute = "trip";
      # difft takes file pairs, not `diff -u`. `command diff` for the unix one
      diff = "difft";
    };

    # abbreviations, not aliases: these expand in place so the flags are
    # visible and editable before the command runs
    shellAbbrs = {
      du = "dust";
      gl = "serie";
      http = "xh";
      lg = "lazygit";
      md = "glow";
      mon = "macmon";
      pack = "ouch compress";
      unpack = "ouch decompress";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    flags = [ "--disable-up-arrow" ];
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    historyWidget.command = "";
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    # upstream's default became "y" in stateVersion 26.05. pinned explicitly so
    # it does not silently change under us on a stateVersion bump
    shellWrapperName = "y";
  };

  home.file.".config/fastfetch/config.jsonc".text = builtins.toJSON {
    "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json";
    modules = [
      "title"
      "separator"
      "os"
      "host"
      "kernel"
      "uptime"
      "packages"
      "shell"
      "terminal"
      {
        type = "command";
        key = "Nix";
        text = ''echo "Lix $(/run/current-system/sw/bin/nix --version | head -1 | awk '{print $NF}')"'';
      }
      "cpu"
      "gpu"
      "memory"
      "disk"
      "battery"
      "datetime"
      "break"
      "colors"
    ];
  };
}
