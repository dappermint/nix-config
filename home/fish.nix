{
  programs.fish.enable = true;

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
