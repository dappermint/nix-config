{ inputs, ... }:
{
  home.file.".claude/CLAUDE.md".source = "${inputs.claude-config}/CLAUDE.md";
  home.file.".claude/output-styles".source = "${inputs.claude-config}/output-styles";
}
