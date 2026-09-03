# droid only. portrait on a phone is roughly 50 columns, so the prompt is one
# line of context and one line to type on, with the path truncated hard
{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;

    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$nix_shell$python$rust$golang$cmd_duration$line_break$character";

      directory = {
        truncation_length = 2;
        truncate_to_repo = true;
        style = "bold cyan";
      };

      git_branch = {
        format = "[$branch]($style) ";
        style = "bold purple";
      };

      git_status.style = "bold yellow";
      nix_shell.format = "[nix]($style) ";

      cmd_duration = {
        min_time = 2000;
        format = "[$duration]($style) ";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
    };
  };
}
