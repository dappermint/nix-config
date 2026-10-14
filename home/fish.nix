{ pkgs, ... }:

let
  # as in home/git.nix: rubicon has no /run/current-system to read nix out of
  nixBin = if pkgs.stdenv.hostPlatform.isDarwin then "/run/current-system/sw/bin/nix" else "nix";
in
{
  programs.fish.enable = true;

  # home-manager's fish module turns this on by mkDefault for man completions,
  # but from stateVersion 26.05 programs.man.package is null on darwin and
  # /usr/bin/man uses macos' own whatis db, so the generated cache is built and
  # then never read
  programs.man.generateCaches = false;

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
    }
    // (pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      sbxrdp = "sdl-freerdp /v:10.212.240.196 /u:sbx /p:$SBX_RDP_PASSWORD /cert:ignore +clipboard +dynamic-resolution";
    });

    shellAbbrs = {
      du = "dust";
      gl = "serie";
      http = "xh";
      lg = "lazygit";
      md = "glow";
      pack = "ouch compress";
      unpack = "ouch decompress";
    }
    // (pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      mon = "macmon";
    });
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      enter_accept = true;
      sync.records = true;
    };
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
        text = ''echo "Lix $(${nixBin} --version | head -1 | awk '{print $NF}')"'';
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
