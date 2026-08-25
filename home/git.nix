let
  # git and jj sign the same commits as the same person, so the identity and
  # signing key are declared once rather than kept in sync by hand. the key is
  # the same ed25519 that backs sops
  identity = {
    name = "millia ampora";
    email = "198710911+dappermint@users.noreply.github.com";
  };
  signingKey = "~/.ssh/id_ed25519.pub";
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
    settings = {
      user.name = identity.name;
      user.email = identity.email;
      user.signingkey = signingKey;
      gpg.format = "ssh";
      commit.gpgsign = true;
      tag.gpgsign = true;
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
      credential."https://github.com".helper = "!/run/current-system/sw/bin/gh auth git-credential";
      credential."https://gist.github.com".helper = "!/run/current-system/sw/bin/gh auth git-credential";
    };
  };
}
