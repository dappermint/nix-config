{ pkgs, ... }:

let
  keys = import ../lib/keys.nix;
  identity = {
    name = "millia ampora";
    email = "198710911+dappermint@users.noreply.github.com";
  };
  # secure enclave key on apollo (see ssh.nix), the sops ed25519 elsewhere
  signingKey =
    if pkgs.stdenv.hostPlatform.isDarwin then "~/.ssh/id_enclave.pub" else "~/.ssh/id_ed25519.pub";

in
{
  programs.jujutsu = {
    enable = true;
    settings = {
      user = identity;
      signing = {
        behavior = "own";
        backend = "ssh";
        key = signingKey;
      };
    };
  };

  # difftool wired by hand: home-manager refuses difftastic.git.enable beside
  # delta.enableGitIntegration. delta keeps `git diff`, difft answers `git difftool`
  programs.difftastic.enable = true;

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
    };
  };

  programs.git = {
    enable = true;
    ignores = [
      "**/.claude"
      "**/.aider*"
      "**/.cursor"
      "**/.continue"
      "**/.copilot"
      "**/.codeium"
      "**/.antigravitycli"
      "**/CLAUDE.md"
      "**/AGENTS.md"
      "**/agents.md"
      "**/gemini.md"
      "**/.gemini.md"
      "**/.direnv"
    ];
    signing = {
      key = signingKey;
      format = "ssh";
      signByDefault = true;
      # the ed25519 stays listed so commits signed before the enclave key still verify
      allowedSigners = ''
        ${identity.email} ${keys.ed25519}
        ${identity.email} ${keys.enclave}
      '';
    };
    settings = {
      user.name = identity.name;
      user.email = identity.email;
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      push.default = "simple";
      push.followTags = true;
      pull.rebase = false;
      fetch.prune = true;
      fetch.pruneTags = true;
      fetch.parallel = 0;
      rebase.autoStash = true;
      rebase.autoSquash = true;
      rebase.updateRefs = true;
      merge.conflictStyle = "zdiff3";
      rerere.enabled = true;
      rerere.autoUpdate = true;
      diff.algorithm = "histogram";
      diff.colorMoved = "default";
      diff.tool = "difftastic";
      difftool.prompt = false;
      difftool.difftastic.cmd = ''difft "$LOCAL" "$REMOTE"'';
      diff.mnemonicPrefix = true;
      diff.renames = true;
      column.ui = "auto";
      branch.sort = "-committerdate";
      tag.sort = "version:refname";
      help.autocorrect = "prompt";
      commit.verbose = true;
      log.date = "iso";
      core.untrackedCache = true;
    };
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      aliases.co = "pr checkout";
    };
    gitCredentialHelper.hosts = [
      "https://github.com"
      "https://gist.github.com"
    ];
  };
}
