{
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
      user.name = "Liah Yoffe";
      user.email = "liahyoffe@gmail.com";
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
